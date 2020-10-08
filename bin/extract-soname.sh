#!/usr/bin/env python2.7

"""
Extract SONAME of a shared library.                     
"""

import sys

if len(sys.argv) < 2:
    print('usage: ' + sys.argv[0] + ' <library path>')
    sys.exit(0)
filename = sys.argv[1]

try:
    import elftools
except ImportError:
    import re
    import subprocess

    def get_soname(filename):

        try:
            out = subprocess.check_output(['objdump', '-p', filename])
        except:
            return ''
        else:
            result = re.search('^\s+SONAME\s+(.+)$',out,re.MULTILINE)
            if result:
                return result.group(1)
            else:
                return ''
    
else:
    import ctypes
    import elftools.elf.elffile as elffile
    import elftools.construct.macros as macros
    import elftools.elf.structs as structs

    def get_soname(filename):

        stream = open(filename, 'rb')
        f = elffile.ELFFile(stream)
        dynamic = f.get_section_by_name('.dynamic')
        dynstr = f.get_section_by_name('.dynstr')

        # Handle libraries built for different machine architectures:         
        if f.header['e_machine'] == 'EM_X86_64':
            st = structs.Struct('Elf64_Dyn',
                                macros.ULInt64('d_tag'),
                                macros.ULInt64('d_val'))
        elif f.header['e_machine'] == 'EM_386':
            st = structs.Struct('Elf32_Dyn',
                                macros.ULInt32('d_tag'),
                                macros.ULInt32('d_val'))
        else:
            raise RuntimeError('unsupported machine architecture')

        entsize = dynamic['sh_entsize']
        for k in xrange(dynamic['sh_size']/entsize):
            result = st.parse(dynamic.data()[k*entsize:(k+1)*entsize])

            # The following value for the SONAME tag is specified in elf.h:  
            if result.d_tag == 14:
                return dynstr.get_string(result.d_val)
            
soname = get_soname(filename)
if soname:
    print('SONAME: %s' % soname)
else:
    print('no SONAME found')
