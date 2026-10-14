mod snapshot_config;

use std::{ffi::OsStr, path::Path};

use codesnap::{
    snapshot::{image_snapshot::ImageSnapshot, snapshot_data::SnapshotData},
    themes,
};
use mlua::prelude::*;
use snapshot_config::SnapshotConfigLua;

fn prepare_snapshot_config(cfg: &mut codesnap::config::SnapshotConfig) {
    let mut db = cosmic_text::fontdb::Database::new();
    let mut font_dirs: Vec<String> = Vec::new();

    #[cfg(target_os = "macos")]
    {
        if let Ok(home) = std::env::var("HOME") {
            font_dirs.push(format!("{}/Library/Fonts", home));
        }
        font_dirs.push("/Library/Fonts".to_string());
        font_dirs.push("/System/Library/Fonts".to_string());
        font_dirs.push("/System/Library/Fonts/Supplemental".to_string());
        font_dirs.push(
            "/System/Applications/Utilities/Terminal.app/Contents/Resources/Fonts".to_string(),
        );
        font_dirs.push(
            "/Applications/Xcode.app/Contents/SharedFrameworks/DVTKit.framework/Resources/Fonts"
                .to_string(),
        );
    }

    #[cfg(target_os = "linux")]
    {
        if let Ok(home) = std::env::var("HOME") {
            font_dirs.push(format!("{}/.local/share/fonts", home));
            font_dirs.push(format!("{}/.fonts", home));
        }
        font_dirs.push("/usr/share/fonts".to_string());
        font_dirs.push("/usr/local/share/fonts".to_string());
    }

    #[cfg(target_os = "windows")]
    {
        if let Ok(windir) = std::env::var("WINDIR") {
            font_dirs.push(format!("{}\\Fonts", windir));
        } else {
            font_dirs.push("C:\\Windows\\Fonts".to_string());
        }
        if let Ok(local_app_data) = std::env::var("LOCALAPPDATA") {
            font_dirs.push(format!("{}\\Microsoft\\Windows\\Fonts", local_app_data));
        }
    }

    for folder in &cfg.fonts_folders {
        if Path::new(folder).exists() {
            db.load_fonts_dir(folder);
        }
    }

    for dir in font_dirs {
        if Path::new(&dir).exists() {
            db.load_fonts_dir(&dir);
            if !cfg.fonts_folders.contains(&dir) {
                cfg.fonts_folders.push(dir);
            }
        }
    }

    let resolved_code_font = resolve_font_family(&db, &cfg.code_config.font_family);
    cfg.code_config.font_family = resolved_code_font.clone();
    cfg.code_config.breadcrumbs.font_family =
        resolve_font_family(&db, &cfg.code_config.breadcrumbs.font_family);
    cfg.window.title_config.font_family =
        resolve_font_family(&db, &cfg.window.title_config.font_family);

    if let Some(ref mut watermark) = cfg.watermark {
        watermark.font_family = resolve_font_family(&db, &watermark.font_family);
    }
}

fn create_image_snapshot_by_config(config: &SnapshotConfigLua) -> LuaResult<ImageSnapshot> {
    let mut cfg = config.0.clone();
    prepare_snapshot_config(&mut cfg);
    cfg.create_snapshot()
        .map_err(|e| mlua::Error::RuntimeError(format!("Failed to create snapshot: {}", e)))
}

fn save(_: &Lua, (file_path, config): (String, SnapshotConfigLua)) -> LuaResult<()> {
    let path = Path::new(&file_path);
    let actual_path = if let Some(ext) = path.extension().and_then(OsStr::to_str) {
        if ext.to_lowercase() != "png" {
            path.with_extension("png").to_string_lossy().to_string()
        } else {
            file_path.clone()
        }
    } else {
        format!("{}.png", file_path)
    };

    let snapshot = create_image_snapshot_by_config(&config)?;
    let png_data = snapshot
        .png_data()
        .map_err(|e| mlua::Error::RuntimeError(format!("Failed to generate PNG data: {}", e)))?;

    png_data.save(&actual_path).map_err(|_| {
        mlua::Error::RuntimeError(format!("Failed to save snapshot data to {}", actual_path))
    })
}

#[cfg(target_os = "macos")]
fn copy_png_macos(png_bytes: &[u8]) -> Result<(), String> {
    use objc2::msg_send;
    use objc2::rc::autoreleasepool;
    use objc2::runtime::{AnyClass, AnyObject};
    use std::ffi::c_void;

    autoreleasepool(|_| -> Result<(), String> {
        let cls_nspasteboard = AnyClass::get(c"NSPasteboard")
            .ok_or_else(|| "NSPasteboard class not found".to_string())?;
        let cls_nsdata =
            AnyClass::get(c"NSData").ok_or_else(|| "NSData class not found".to_string())?;
        let cls_nsstring =
            AnyClass::get(c"NSString").ok_or_else(|| "NSString class not found".to_string())?;

        unsafe {
            let pasteboard: *mut AnyObject = msg_send![cls_nspasteboard, generalPasteboard];
            if pasteboard.is_null() {
                return Err("Failed to get generalPasteboard".to_string());
            }

            let _: isize = msg_send![pasteboard, clearContents];

            let data: *mut AnyObject = msg_send![
                cls_nsdata,
                dataWithBytes: png_bytes.as_ptr() as *const c_void,
                length: png_bytes.len()
            ];
            if data.is_null() {
                return Err("Failed to create NSData from PNG bytes".to_string());
            }

            let type_str: *mut AnyObject = msg_send![
                cls_nsstring,
                stringWithUTF8String: c"public.png".as_ptr()
            ];
            if type_str.is_null() {
                return Err("Failed to create NSString for public.png".to_string());
            }

            let success: bool = msg_send![pasteboard, setData: data, forType: type_str];
            if !success {
                return Err("Failed to set PNG data to NSPasteboard".to_string());
            }
        }
        Ok(())
    })
}

fn copy_image_to_clipboard(
    png_bytes: &[u8],
    #[allow(unused_variables)] raw_rgba: &[u8],
    #[allow(unused_variables)] width: usize,
    #[allow(unused_variables)] height: usize,
) -> Result<(), String> {
    // 1. macOS native: write public.png directly to NSPasteboard (instantaneous, pure PNG, no TIFF)
    #[cfg(target_os = "macos")]
    {
        copy_png_macos(png_bytes)
    }

    // 2. Linux Wayland & X11: stream PNG bytes to wl-copy or xclip
    #[cfg(target_os = "linux")]
    {
        if std::env::var_os("WAYLAND_DISPLAY").is_some()
            || std::env::var_os("WAYLAND_SOCKET").is_some()
        {
            if let Ok(mut child) = std::process::Command::new("wl-copy")
                .args(["--type", "image/png"])
                .stdin(std::process::Stdio::piped())
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .spawn()
            {
                if let Some(mut stdin) = child.stdin.take() {
                    use std::io::Write;
                    let _ = stdin.write_all(png_bytes);
                    let _ = stdin.flush();
                }
                if let Ok(status) = child.wait() {
                    if status.success() {
                        return Ok(());
                    }
                }
            }
        }

        if std::env::var_os("DISPLAY").is_some() {
            if let Ok(mut child) = std::process::Command::new("xclip")
                .args(["-selection", "clipboard", "-target", "image/png"])
                .stdin(std::process::Stdio::piped())
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .spawn()
            {
                if let Some(mut stdin) = child.stdin.take() {
                    use std::io::Write;
                    let _ = stdin.write_all(png_bytes);
                    let _ = stdin.flush();
                }
                if let Ok(status) = child.wait() {
                    if status.success() {
                        return Ok(());
                    }
                }
            }
        }

        let mut clipboard = arboard::Clipboard::new()
            .map_err(|e| format!("Failed to initialize clipboard: {}", e))?;

        let img_data = arboard::ImageData {
            width,
            height,
            bytes: std::borrow::Cow::Borrowed(raw_rgba),
        };

        clipboard
            .set_image(img_data)
            .map_err(|e| format!("Failed to set image to clipboard: {}", e))?;

        Ok(())
    }

    // 3. Windows / Other: arboard fallback
    #[cfg(not(any(target_os = "macos", target_os = "linux")))]
    {
        let mut clipboard = arboard::Clipboard::new()
            .map_err(|e| format!("Failed to initialize clipboard: {}", e))?;

        let img_data = arboard::ImageData {
            width,
            height,
            bytes: std::borrow::Cow::Borrowed(raw_rgba),
        };

        clipboard
            .set_image(img_data)
            .map_err(|e| format!("Failed to set image to clipboard: {}", e))?;

        Ok(())
    }
}

fn copy_text_to_clipboard(text: &str) -> Result<(), String> {
    #[cfg(target_os = "linux")]
    {
        if std::env::var_os("WAYLAND_DISPLAY").is_some()
            || std::env::var_os("WAYLAND_SOCKET").is_some()
        {
            if let Ok(mut child) = std::process::Command::new("wl-copy")
                .stdin(std::process::Stdio::piped())
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .spawn()
            {
                if let Some(mut stdin) = child.stdin.take() {
                    use std::io::Write;
                    let _ = stdin.write_all(text.as_bytes());
                    let _ = stdin.flush();
                }
                if let Ok(status) = child.wait() {
                    if status.success() {
                        return Ok(());
                    }
                }
            }
        }

        if std::env::var_os("DISPLAY").is_some() {
            if let Ok(mut child) = std::process::Command::new("xclip")
                .args(["-selection", "clipboard"])
                .stdin(std::process::Stdio::piped())
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .spawn()
            {
                if let Some(mut stdin) = child.stdin.take() {
                    use std::io::Write;
                    let _ = stdin.write_all(text.as_bytes());
                    let _ = stdin.flush();
                }
                if let Ok(status) = child.wait() {
                    if status.success() {
                        return Ok(());
                    }
                }
            }
        }
    }

    let mut clipboard =
        arboard::Clipboard::new().map_err(|e| format!("Failed to initialize clipboard: {}", e))?;
    clipboard
        .set_text(text)
        .map_err(|e| format!("Failed to set text to clipboard: {}", e))?;

    Ok(())
}

fn copy(_: &Lua, config: SnapshotConfigLua) -> LuaResult<()> {
    let snapshot = create_image_snapshot_by_config(&config)?;
    let png_snapshot = snapshot
        .png_data()
        .map_err(|e| mlua::Error::RuntimeError(format!("Failed to generate PNG data: {}", e)))?;
    let raw_snapshot = snapshot.raw_data().map_err(|e| {
        mlua::Error::RuntimeError(format!("Failed to generate raw image data: {}", e))
    })?;

    let (png_bytes, width, height) = match png_snapshot {
        SnapshotData::Image {
            data,
            width,
            height,
        } => (data, width, height),
        _ => {
            return Err(mlua::Error::RuntimeError(
                "Invalid PNG snapshot data".to_string(),
            ))
        }
    };

    let raw_bytes = match raw_snapshot {
        SnapshotData::Image { data, .. } => data,
        _ => {
            return Err(mlua::Error::RuntimeError(
                "Invalid raw snapshot data".to_string(),
            ))
        }
    };

    copy_image_to_clipboard(&png_bytes, &raw_bytes, width, height)
        .map_err(mlua::Error::RuntimeError)
}

fn copy_ascii(_: &Lua, config: SnapshotConfigLua) -> LuaResult<()> {
    let ascii_snapshot = config.0.create_ascii_snapshot().map_err(|e| {
        mlua::Error::RuntimeError(format!("Failed to create ASCII snapshot: {}", e))
    })?;
    let raw_data = ascii_snapshot
        .raw_data()
        .map_err(|e| mlua::Error::RuntimeError(format!("Failed to generate ASCII data: {}", e)))?;

    let text = match raw_data {
        SnapshotData::Text(t) => t,
        _ => {
            return Err(mlua::Error::RuntimeError(
                "Invalid ASCII snapshot data".to_string(),
            ))
        }
    };

    copy_text_to_clipboard(&text).map_err(mlua::Error::RuntimeError)
}

fn parse_code_theme(_: &Lua, code_theme: String) -> LuaResult<String> {
    // If it's a local theme, return immediately without spinning up a Tokio runtime
    if !code_theme.contains("://") && !code_theme.contains('@') {
        return Ok(code_theme);
    }

    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| mlua::Error::RuntimeError(format!("Failed to create Tokio runtime: {}", e)))?;

    rt.block_on(async {
        themes::parse_code_theme(&code_theme)
            .await
            .map_err(|e| mlua::Error::RuntimeError(format!("Failed to parse code theme: {}", e)))
    })
}

fn get_png_bytes(lua: &Lua, config: SnapshotConfigLua) -> LuaResult<LuaString> {
    let snapshot = create_image_snapshot_by_config(&config)?;
    let png_snapshot = snapshot
        .png_data()
        .map_err(|e| mlua::Error::RuntimeError(format!("Failed to generate PNG data: {}", e)))?;

    match png_snapshot {
        SnapshotData::Image { data, .. } => lua.create_string(&data),
        _ => Err(mlua::Error::RuntimeError(
            "Invalid PNG snapshot data".to_string(),
        )),
    }
}

#[mlua::lua_module(skip_memory_check)]
fn generator(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;

    exports.set("save", lua.create_function(save)?)?;
    exports.set("copy", lua.create_function(copy)?)?;
    exports.set("copy_ascii", lua.create_function(copy_ascii)?)?;
    exports.set("get_png_bytes", lua.create_function(get_png_bytes)?)?;
    exports.set("parse_code_theme", lua.create_function(parse_code_theme)?)?;

    Ok(exports)
}

fn resolve_font_family(db: &cosmic_text::fontdb::Database, requested: &str) -> String {
    let req_lower = requested.to_lowercase();
    let req_trimmed = req_lower.trim();

    let direct_query = cosmic_text::fontdb::Query {
        families: &[cosmic_text::fontdb::Family::Name(requested)],
        weight: cosmic_text::fontdb::Weight::NORMAL,
        stretch: cosmic_text::fontdb::Stretch::Normal,
        style: cosmic_text::fontdb::Style::Normal,
    };
    if db.query(&direct_query).is_some() {
        return requested.to_string();
    }

    let mut best_match: Option<(String, bool)> = None;

    for face in db.faces() {
        for (fam, _) in &face.families {
            let fam_lower = fam.to_lowercase();
            if fam_lower == req_trimmed {
                if face.monospaced {
                    return fam.clone();
                } else if best_match.is_none() || !best_match.as_ref().unwrap().1 {
                    best_match = Some((fam.clone(), face.monospaced));
                }
            }
            if (fam_lower == format!("{} mono", req_trimmed)
                || fam_lower == format!("{} nerd font mono", req_trimmed.replace(" nerd font", "")))
                && face.monospaced
            {
                return fam.clone();
            }
        }
    }

    if let Some((fam, _)) = best_match {
        return fam;
    }

    #[cfg(target_os = "macos")]
    {
        for fallback in ["Menlo", "Monaco", "Courier", "CaskaydiaCove Nerd Font"] {
            let q = cosmic_text::fontdb::Query {
                families: &[cosmic_text::fontdb::Family::Name(fallback)],
                weight: cosmic_text::fontdb::Weight::NORMAL,
                stretch: cosmic_text::fontdb::Stretch::Normal,
                style: cosmic_text::fontdb::Style::Normal,
            };
            if db.query(&q).is_some() {
                return fallback.to_string();
            }
        }
    }

    #[cfg(target_os = "linux")]
    {
        for fallback in [
            "DejaVu Sans Mono",
            "FreeMono",
            "Liberation Mono",
            "monospace",
            "CaskaydiaCove Nerd Font",
        ] {
            let q = cosmic_text::fontdb::Query {
                families: &[cosmic_text::fontdb::Family::Name(fallback)],
                weight: cosmic_text::fontdb::Weight::NORMAL,
                stretch: cosmic_text::fontdb::Stretch::Normal,
                style: cosmic_text::fontdb::Style::Normal,
            };
            if db.query(&q).is_some() {
                return fallback.to_string();
            }
        }
    }

    #[cfg(target_os = "windows")]
    {
        for fallback in [
            "Consolas",
            "Cascadia Code",
            "Courier New",
            "CaskaydiaCove Nerd Font",
        ] {
            let q = cosmic_text::fontdb::Query {
                families: &[cosmic_text::fontdb::Family::Name(fallback)],
                weight: cosmic_text::fontdb::Weight::NORMAL,
                stretch: cosmic_text::fontdb::Stretch::Normal,
                style: cosmic_text::fontdb::Style::Normal,
            };
            if db.query(&q).is_some() {
                return fallback.to_string();
            }
        }
    }

    "CaskaydiaCove Nerd Font".to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_font_fallback_always_resolves() {
        let fs = cosmic_text::FontSystem::new();
        let font = resolve_font_family(fs.db(), "nonexistent_custom_font_12345");
        assert!(!font.is_empty());
    }
}
