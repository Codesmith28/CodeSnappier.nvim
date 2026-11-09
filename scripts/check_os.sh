os="Unknown"
uname_output=$(uname -s)
uname_m_output=$(uname -m)

case "$uname_output" in
  Darwin)
    case "$uname_m_output" in
      arm64|aarch64) os="mac-aarch64" ;;
      x86_64|amd64)  os="mac-x86_64" ;;
      *) echo "Unknown macOS architecture: $uname_m_output" ;;
    esac
    ;;
  Linux)
    case "$uname_m_output" in
      aarch64|arm64) os="linux-aarch64" ;;
      x86_64|amd64)  os="linux-x86_64" ;;
      *) echo "Unknown Linux architecture: $uname_m_output" ;;
    esac
    ;;
  CYGWIN*|MINGW*|MSYS*)
    os="windows-x86_64"
    ;;
  *)
    echo "Unknown platform: $uname_output"
    ;;
esac
