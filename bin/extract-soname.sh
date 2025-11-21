#!/usr/bin/env python3

"""
Extract SONAME of a shared library.

This script extracts the SONAME (shared object name) from ELF shared libraries.
It will attempt to use pyelftools if available, otherwise falls back to objdump.
"""

import sys
import os
from pathlib import Path


def print_usage():
    """Print usage information and exit."""
    print(f'Usage: {sys.argv[0]} <library path>')
    print('\nExtracts the SONAME from an ELF shared library.')
    print('\nExample:')
    print(f'  {sys.argv[0]} /usr/lib/x86_64-linux-gnu/libc.so.6')
    sys.exit(1)


def get_soname_with_elftools(filename):
    """Extract SONAME using pyelftools library."""
    try:
        from elftools.elf.elffile import ELFFile
        from elftools.elf.dynamic import DynamicSection
    except ImportError as e:
        raise ImportError('pyelftools not available') from e

    try:
        with open(filename, 'rb') as f:
            elf_file = ELFFile(f)
            
            # Look for the dynamic section
            for section in elf_file.iter_sections():
                if not isinstance(section, DynamicSection):
                    continue
                
                # Search for SONAME tag (DT_SONAME = 14)
                for tag in section.iter_tags():
                    if tag.entry.d_tag == 'DT_SONAME':
                        return tag.soname
            
            return None
            
    except (OSError, IOError) as e:
        print(f'Error reading file: {e}', file=sys.stderr)
        sys.exit(2)
    except Exception as e:
        print(f'Error parsing ELF file: {e}', file=sys.stderr)
        sys.exit(2)


def get_soname_with_objdump(filename):
    """Extract SONAME using objdump as fallback."""
    import re
    import subprocess
    
    try:
        result = subprocess.run(
            ['objdump', '-p', filename],
            capture_output=True,
            text=True,
            check=True
        )
        
        match = re.search(r'^\s+SONAME\s+(.+)$', result.stdout, re.MULTILINE)
        return match.group(1) if match else None
        
    except subprocess.CalledProcessError as e:
        print(f'Error running objdump: {e}', file=sys.stderr)
        sys.exit(2)
    except FileNotFoundError:
        print('Error: objdump not found in PATH', file=sys.stderr)
        sys.exit(2)


def main():
    """Main entry point."""
    if len(sys.argv) < 2 or sys.argv[1] in ('-h', '--help'):
        print_usage()
    
    filename = sys.argv[1]
    
    # Validate input file
    if not os.path.exists(filename):
        print(f'Error: File not found: {filename}', file=sys.stderr)
        sys.exit(2)
    
    if not os.path.isfile(filename):
        print(f'Error: Not a file: {filename}', file=sys.stderr)
        sys.exit(2)
    
    if not os.access(filename, os.R_OK):
        print(f'Error: File not readable: {filename}', file=sys.stderr)
        sys.exit(2)
    
    # Try pyelftools first, fall back to objdump
    try:
        soname = get_soname_with_elftools(filename)
    except ImportError:
        soname = get_soname_with_objdump(filename)
    
    # Print result
    if soname:
        print(f'SONAME: {soname}')
        sys.exit(0)
    else:
        print('No SONAME found')
        sys.exit(1)


if __name__ == '__main__':
    main()
