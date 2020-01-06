from setuptools import setup, find_packages
from distutils.extension import Extension

try:
    from Cython.Distutils import build_ext
except ImportError:
    use_cython = False
else:
    use_cython = True
import sys
import os
from os.path import join, dirname
import codecs
import re


def local_file(filename):
    return codecs.open(
        os.path.join(os.path.dirname(__file__), filename), 'r', 'utf-8'
    )


version = re.search(
    "^version_info = \((\d+), (\d+), (\d+)\)",
    local_file(os.path.join('pyhytechdb', '__init__.py')).read(),
    re.MULTILINE
).groups()

cmdclass = {}
ext_modules = []
data_files = [('', ['./README.md']),]
depends = ["pyhytechdb/c_hscli.h"]
sources = ["pyhytechdb/htcore.pyx", "pyhytechdb/c_hscli.c"]

ext_modules.append(Extension("pyhytechdb.htcore", sources, depends=depends))

if use_cython:
    cmdclass.update({'build_ext': build_ext})

if sys.version_info < (3, 5):
    raise RuntimeError('pyhytechdb requires Python 3.5 or greater')

with open("README.md", "r") as fh:
    long_description = fh.read()

setup(name="pyhytechdb",
      version='.'.join(version),
      keywords=['Hytech'],
      license='MIT License',
      author='Aleksandr Osipov',
      author_email='aleksandr.osipov@zoho.eu',
      packages=find_packages(),
      data_files=data_files,
      description='pyhytechdb package is a set of DBMS HyTech(https://hytechdb.ru/)',
      long_description=long_description,
      long_description_content_type="text/markdown",
      url='https://github.com/a-osipov/pyhytechdb',
      cmdclass=cmdclass,
      ext_modules=ext_modules,
      classifiers=[
          'License :: OSI Approved :: MIT License',
          'Programming Language :: Python :: 3.5',
          'Programming Language :: Python :: 3.6',
          "Operating System :: Microsoft :: Windows",
      ]
      )
