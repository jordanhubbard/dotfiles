# Scripts Directory

This directory contains utility scripts for various tasks. All scripts have been enhanced with modern best practices, comprehensive error handling, and detailed help documentation.

## Quick Reference

### System & Development Tools

#### extract-soname.sh
Extract SONAME from ELF shared libraries.

```bash
extract-soname.sh /usr/lib/libc.so.6
```

#### install-hashicorp.sh
Install HashiCorp tools (Terraform, Vault, Consul, etc.) on Debian/Ubuntu.

```bash
install-hashicorp.sh              # Install default set
install-hashicorp.sh terraform    # Install only Terraform
```

#### llvm-bootstrap.sh
Build and install LLVM/Clang from source.

```bash
llvm-bootstrap.sh                 # Build with auto-detected cores
llvm-bootstrap.sh -j 8            # Use 8 parallel jobs
llvm-bootstrap.sh -r              # Resume interrupted build
```

### File & System Management

#### link-sed.sh
Bulk update symlinks by replacing path components.

```bash
link-sed.sh -d /old/path /new/path ~/bin/*    # Dry run
link-sed.sh /usr/local /opt/local ~/.local/*  # Update symlinks
```

#### mount-sshfs.sh
Mount remote filesystems via SSHFS.

```bash
mount-sshfs.sh myhost                         # Mount root@myhost.local:/dos/
mount-sshfs.sh -u pi -r /home mypi            # Custom user and path
```

### Jupyter & Data Science

#### start-jupyter.sh
Start Jupyter Notebook (local or Docker with GPU).

```bash
start-jupyter.sh                  # Bare-metal mode
start-jupyter.sh -d               # Docker mode with GPU
start-jupyter.sh -p 9999          # Use custom port
```

#### open-notebook.sh
Connect to remote Jupyter server and open in browser.

```bash
open-notebook.sh                  # Connect to default host
open-notebook.sh -H myserver.local # Custom host
```

### Docker Tools

#### run
Execute commands in a Docker development container.

```bash
run ls -la                        # List files in container
run make test                     # Run tests
run python script.py              # Run Python script
```

### AI & Document Processing

#### summarize-document.py / summarize.sh
Summarize documents using Ollama LLM.

```bash
summarize.sh paper.pdf "Summarize this research paper"
summarize.sh -m llama2 notes.txt "Extract key points"
```

### Network Tools

#### wakehost.sh
Wake up computers using Wake-on-LAN.

```bash
wakehost.sh -l                    # List registered hosts
wakehost.sh megamind              # Wake up megamind
```

### Utilities

#### worldclock.sh
Display a graphical world clock with multiple timezones.

```bash
worldclock.sh                     # Launch GUI clock
```

## Getting Help

All scripts support the `-h` or `--help` flag for detailed usage information:

```bash
script-name.sh -h
```

## Common Features

All scripts include:

- ✅ **Comprehensive help** - Use `-h` flag for detailed usage
- ✅ **Error handling** - Clear error messages with troubleshooting hints
- ✅ **Input validation** - Validates arguments before processing
- ✅ **Progress indicators** - Shows what's happening during long operations
- ✅ **Colored output** - Info (blue), warnings (yellow), errors (red)
- ✅ **Proper exit codes** - 0 for success, non-zero for errors

## Installation

Make sure all scripts are executable:

```bash
chmod +x bin/*.sh bin/*.py
```

Add the bin directory to your PATH:

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Dependencies

Some scripts require additional tools:

- **extract-soname.sh**: python3, pyelftools (optional), objdump
- **install-hashicorp.sh**: curl, gpg, apt (Debian/Ubuntu only)
- **llvm-bootstrap.sh**: git, cmake, make, clang or gcc
- **mount-sshfs.sh**: sshfs, macFUSE (macOS)
- **start-jupyter.sh**: jupyter or docker (with nvidia-docker for GPU)
- **summarize-document.py**: python3, requests, pdfplumber (for PDFs)
- **wakehost.sh**: wakeonlan or etherwake
- **worldclock.sh**: Tcl/Tk (wish)

Install missing dependencies as prompted by error messages.

## Troubleshooting

### Common Issues

**Permission denied**
```bash
chmod +x bin/script-name.sh
```

**Command not found**
```bash
# Make sure bin directory is in PATH
echo $PATH | grep bin
```

**Python module not found**
```bash
pip3 install requests pdfplumber pyelftools
```

**Docker daemon not running**
```bash
# Start Docker Desktop (macOS) or docker service (Linux)
systemctl start docker
```

### Getting More Help

Each script provides detailed error messages. If you encounter issues:

1. Run with `-h` flag to see usage instructions
2. Check error messages for specific troubleshooting steps
3. Ensure all dependencies are installed
4. Verify file permissions and paths

## Contributing

When modifying scripts, maintain these standards:

1. **Error Handling**: Use `set -euo pipefail` in bash scripts
2. **Documentation**: Update help text and this README
3. **Validation**: Check inputs before processing
4. **Exit Codes**: Return appropriate codes (0 = success)
5. **Testing**: Test with valid and invalid inputs

## License

See [LICENSE.md](../LICENSE.md) in the root directory.

