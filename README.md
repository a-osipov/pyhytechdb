# Pyhytechdb
pyhytechdb package is a set of [DBMS HyTech](https://hytechdb.ru/)
bindings for Python Pure python or Cython.
Python Database API Specification v2.0
It works on Python 3.5+.
Windows only
For work you need:
- hscli.dll - [API of the client part of DBMS HyTech 2.5](https://hytechdb.ru/index.php?s=prod)
- hsheap.dll
- hsinpt.dll
- hslogf.dl

## Getting Started
```
import pyhytechdb

user = 'test'
passwd = 'test'
hdb = 'tcpip:/localhost:1000'

with pyhytechdb.connect(hdb, user, passwd) as connection:
    with connection.cursor() as cur:
        cur.execute("select * from foo;")
        print(cur.fetchone())
```

### Installing
pip install pyhytechdb

## Running the tests
setup test

## Authors
**Aleksandr Osipov**
aleksandr.osipov@zoho.eu

## License
This project is licensed under the MIT License
