mod snapshot_config;

use std::{ffi::OsStr, path::Path};

use codesnap::{
    snapshot::{image_snapshot::ImageSnapshot, snapshot_data::SnapshotData},
    themes,
};
use mlua::prelude::*;
use snapshot_config::SnapshotConfigLua;

enum SnapshotType {
    Png,
    Svg,
    Html,
}

impl From<String> for SnapshotType {
    fn from(value: String) -> Self {
        match value.as_str() {
            "png" => SnapshotType::Png,
            "svg" => SnapshotType::Svg,
            "html" => SnapshotType::Html,
            _ => SnapshotType::Png,
        }
    }
}

impl SnapshotType {
    fn snapshot_data(
        &self,
        image_snapshot: ImageSnapshot,
        is_raw: bool,
    ) -> LuaResult<SnapshotData> {
        let data = match self {
            SnapshotType::Png => {
                if is_raw {
                    image_snapshot.raw_data()
                } else {
                    image_snapshot.png_data()
                }
            }
            SnapshotType::Svg => image_snapshot.svg_data(),
            SnapshotType::Html => image_snapshot.html_data(),
        }
        .map_err(|_| mlua::Error::RuntimeError("Failed to generate snapshot data".to_string()))?;

        Ok(data)
    }
}

fn create_image_snapshot_by_config(config: &SnapshotConfigLua) -> LuaResult<ImageSnapshot> {
    config
        .0
        .create_snapshot()
        .map_err(|e| mlua::Error::RuntimeError(format!("Failed to create snapshot: {}", e)))
}

fn save(_: &Lua, (file_path, config): (String, SnapshotConfigLua)) -> LuaResult<()> {
    let snapshot_type: SnapshotType = Path::new(&file_path)
        .extension()
        .and_then(OsStr::to_str)
        .unwrap_or("png")
        .to_string()
        .into();

    snapshot_type
        .snapshot_data(create_image_snapshot_by_config(&config)?, false)?
        .save(&file_path)
        .map_err(|_| {
            mlua::Error::RuntimeError(format!("Failed to save snapshot data to {}", file_path))
        })
}

fn copy_image_to_clipboard(
    png_bytes: &[u8],
    raw_rgba: &[u8],
    width: usize,
    height: usize,
) -> Result<(), String> {
    // 1. On Linux Wayland: wl-copy with PNG bytes is instantaneous and native to Wayland
    #[cfg(target_os = "linux")]
    {
        if std::env::var_os("WAYLAND_DISPLAY").is_some() || std::env::var_os("WAYLAND_SOCKET").is_some() {
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

        // 2. On Linux X11: xclip with PNG bytes
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
    }

    // 3. Fallback: arboard without the artificial 1-second delay from codesnap crate
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

fn copy_text_to_clipboard(text: &str) -> Result<(), String> {
    #[cfg(target_os = "linux")]
    {
        if std::env::var_os("WAYLAND_DISPLAY").is_some() || std::env::var_os("WAYLAND_SOCKET").is_some() {
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

    let mut clipboard = arboard::Clipboard::new()
        .map_err(|e| format!("Failed to initialize clipboard: {}", e))?;
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
    let raw_snapshot = snapshot
        .raw_data()
        .map_err(|e| mlua::Error::RuntimeError(format!("Failed to generate raw image data: {}", e)))?;

    let (png_bytes, width, height) = match png_snapshot {
        SnapshotData::Image { data, width, height } => (data, width, height),
        _ => return Err(mlua::Error::RuntimeError("Invalid PNG snapshot data".to_string())),
    };

    let raw_bytes = match raw_snapshot {
        SnapshotData::Image { data, .. } => data,
        _ => return Err(mlua::Error::RuntimeError("Invalid raw snapshot data".to_string())),
    };

    copy_image_to_clipboard(&png_bytes, &raw_bytes, width, height)
        .map_err(mlua::Error::RuntimeError)
}

fn copy_ascii(_: &Lua, config: SnapshotConfigLua) -> LuaResult<()> {
    let ascii_snapshot = config
        .0
        .create_ascii_snapshot()
        .map_err(|e| mlua::Error::RuntimeError(format!("Failed to create ASCII snapshot: {}", e)))?;
    let raw_data = ascii_snapshot
        .raw_data()
        .map_err(|e| mlua::Error::RuntimeError(format!("Failed to generate ASCII data: {}", e)))?;

    let text = match raw_data {
        SnapshotData::Text(t) => t,
        _ => return Err(mlua::Error::RuntimeError("Invalid ASCII snapshot data".to_string())),
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
        _ => Err(mlua::Error::RuntimeError("Invalid PNG snapshot data".to_string())),
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
