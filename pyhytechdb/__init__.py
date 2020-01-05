##############################################################################
# Python  module for HyTech. https://hytechdb.ru/
# Python Database API Specification v2.0
##############################################################################

import datetime

DEBUG = False
HEAPCTRL = 20000 #Размер буфера при чтении результата запроса

version_info = (1, 0, 2)
__version__ = '1.0.2'
apilevel = '2.0'
threadsafety = 1
paramstyle = 'pyformat'

Date = datetime.date
Time = datetime.time
TimeDelta = datetime.timedelta
Timestamp = datetime.datetime


class DBAPITypeObject:
    def __init__(self, *values):
        self.values = values

    def __cmp__(self, other):
        if other in self.values:
            return 0
        if other < self.values:
            return 1
        else:
            return -1


from pyhytechdb.htcore import (HSCLI_ET_CHAR, HSCLI_ET_ARRA, HSCLI_ET_BYTE,
                               HSCLI_ET_INTR, HSCLI_ET_WORD, HSCLI_ET_DATE,
                               HSCLI_ET_NMBR, HSCLI_ET_LONG, HSCLI_ET_DWRD,
                               HSCLI_ET_FLOA, HSCLI_ET_CURR, HSCLI_ET_DFLT,
                               freelibrary, pydate2htdate)
STRING = DBAPITypeObject(HSCLI_ET_CHAR)
BINARY = DBAPITypeObject(HSCLI_ET_ARRA)
NUMBER = DBAPITypeObject(HSCLI_ET_BYTE, HSCLI_ET_INTR, HSCLI_ET_WORD,
                        HSCLI_ET_DATE, HSCLI_ET_NMBR, HSCLI_ET_LONG,
                        HSCLI_ET_DWRD, HSCLI_ET_FLOA, HSCLI_ET_CURR,
                        HSCLI_ET_DFLT)
DATETIME = DBAPITypeObject()
DATE = DBAPITypeObject()
TIME = DBAPITypeObject()
ROWID = DBAPITypeObject()


from pyhytechdb.htcore import (Connection, freelibrary)


def connect(*args, **kwargs):
    """
    DB-API Factory function
    for htcore.Connection
    """
    return Connection(*args, **kwargs)
