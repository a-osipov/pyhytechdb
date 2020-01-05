
from libc.stdlib cimport malloc, realloc, free
from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from cpython.exc cimport PyErr_Fetch, PyErr_Restore
cimport cython
import logging
import binascii
import datetime
import collections

cimport htcore
from .errors import *
from pyhytechdb import DEBUG, HEAPCTRL

log = logging.getLogger(__name__)
log.setLevel(logging.DEBUG)


cdef unsigned HSCLI_ATTR_FLD_VERBOSE		 = 1001	#/* [conn/stmt] Расширенная информация о полях (int) */
cdef unsigned HSCLI_ATTR_CONN_USER_INFO	     = 1002	#/* [conn/stmt] Информация пользователя (long) */
cdef unsigned HSCLI_ATTR_CBK_SRVMSG		     = 1100	#/* [conn] Функция обработки сообщений сервера (hcSqlCbkSrvMsgT*) */
cdef unsigned HSCLI_ATTR_CBK_SRVUSERSEND	 = 1101	#/* [conn] Функция обработки пользовательских сообщений сервера (hcSqlCbkSrvUserSendT*) */
cdef unsigned HSCLI_ATTR_CBK_STMT_SRVMSG	 = 1102	#/* [stmt] Функция обработки сообщений сервера (hcSqlCbkStmtSrvMsgT*) */
cdef unsigned HSCLI_ATTR_CBK_STMT_SRVUSERSEND = 1103	#/* [stmt] Функция обработки пользовательских сообщений сервера

cdef unsigned HSCLI_STMT_DST_INFO	= 107	#/* Информация об колонке результата dst (dstinfo * i) */
cdef unsigned HSCLI_STMT_RC_TYPE	    = 109	#/* Тип retcode (int) */
cdef unsigned HSCLI_STMT_RC_SIZE	    = 110	#/* Длина retcode (int) */
cdef unsigned HSCLI_STMT_RC_BODY	    = 111	#/* Значение retcode (char[], long, double) */
cdef unsigned HSCLI_STMT_CURSNO	    = 140	#/* Номер курсора в HTSQL-сервере (int) */

#/* Получить информацию об операторе */
cdef unsigned HSCLI_STMT_SAB_TYPE       = 102 	#/* тип результата в SAB (int) */
cdef unsigned HSCLI_STMT_SAB_HNDCNT	    = 103	#/* количество ht-обработчиков (int) */
cdef unsigned HSCLI_STMT_SAB_HANDLES	= 104	#/* ht-обработчики (int * i) */
cdef unsigned HSCLI_STMT_ALS_CNT	    = 105	#/* количество alias-ов (int) */

#***** Тип результата в операторе */
cdef HSCLI_RES_NONE = -1	#/* Результата нет */
cdef HSCLI_RES_RECORD = 0	#/* Результат содержит список записей */
cdef HSCLI_RES_JOIN = 3	#/* Результат содержит результат слияния таблиц */
cdef HSCLI_RES_SORTED = 4	#/* Результат содержит отсортированный список записей */
cdef HSCLI_RES_GROUP = 5	#/* Результат содержит результаты операции группировки */
cdef HSCLI_RES_SORTJOIN = 6	#/* Результат содержит отсортированное слияние таблиц */

#/* Получить информацию об соединении */
cdef HSCLI_CONN_SRV_PATH = 101	#/* строка соединения (char[]) */
cdef HSCLI_CONN_SRV_VERS = 102	#/* Версия сервера (double) */
cdef HSCLI_CONN_SRV_VERS2 = 103	#/* Версия сервера (char[]) */
cdef HSCLI_CONN_USER_INFO = 151	#/* Информация пользователя (long) */
cdef HSCLI_CONN_LCLADDR =  152	#/* Адрес (клиента) (char[]) */
cdef HSCLI_CONN_RMTADDR = 153	#/* Адрес (сервера) (char[]) */

#****** Базовые типы данных в БД */
HSCLI_ET_CHAR = 0	#/* Массив символов длиной не более заданной */
HSCLI_ET_ARRA = 1	#/* Массив байтов заданной длины */
HSCLI_ET_BYTE = 2	#/* Элемент - unsigned char (короткое целое) */
HSCLI_ET_INTR = 3	#/* Элемент - signed short */
HSCLI_ET_WORD = 4	#/* Элемент - unsigned short */
HSCLI_ET_DATE = 5	#/* Дата    - unsigned short */
HSCLI_ET_NMBR = 6	#/* Номер   - 3-х байтовое целое без знака */
HSCLI_ET_LONG = 7	#/* Элемент - long int */
HSCLI_ET_DWRD = 8	#/* Элемент - unsigned long int */
HSCLI_ET_FLOA = 9	#/* Элемент - float  */
HSCLI_ET_CURR = 10	#/* Деньги (double)  */
HSCLI_ET_DFLT = 11	#/* Элемент - double */


INITIAL = False
SCALLBACK = None
USCALLBACK = None


def srvusersendlog(message, usertype):
    log.debug("SrvUserSend(%s)" % message)


def srvsendlog(message):
    log.debug("SrvSend(%s)" % message)


def initlibrary():
    """
    initial hscli.dll
    :return:
    """
    initial = globals()['INITIAL']
    if not initial:
        codeerr = htcore.hcsqlinit()
        if codeerr !=0:
            if codeerr == 3001:
                raise InterfaceError("hcSqlInit error hscli.dll")
            raise InterfaceError("hcSqlInit error %d:", codeerr)
    initial = True


def freelibrary():
    """
    free hscli.dll
    :return:
    """
    htcore.hcsqlfree()


cdef class Connection:
    """
    DB-API Connection
    """
    cdef int _is_connected
    cdef int hdb # /* Идентификатор соединения */
    def __init__(self, server=None, user=None, passwd=None):
        initlibrary()
        self._is_connected = 0
        if DEBUG: log.debug("%r: __init__" % self)
        if server and user:
            self.connect(server, user, passwd)

    def connect(self, server, user, passwd):
        codeerr = htcore.hcSqlAllocConnect(&self.hdb)
        if codeerr !=0:
            raise InterfaceError("hcSqlAllocConnect error %d:", codeerr)
        if DEBUG: log.debug("%r: connect(%s, %s, %s)" % (self, server, user, passwd))
        codeerr = htcore.hcSqlConnect(self.hdb,
                                  server.encode('cp866'),
                                  user.encode('cp866'),
                                  passwd.encode('cp866'))
        if codeerr !=0:
            raise DatabaseError("hcSqlConnect error %d:", codeerr)
        if DEBUG:
            self.send_callback(srvsendlog)
            self.usersend_callback(srvusersendlog)
        self._is_connected = 1

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()

    def __del__(self):
        if self._is_connected:
            self.close()

    def close(self):
        """
        DB-API Connection.close()
        """
        if DEBUG: log.debug("%r: close()" % self)
        codeerr = htcore.hcSqlDisconnect(&self.hdb)
        if codeerr !=0:
            InterfaceError("hcSqlDisconnect error %d:", codeerr)
        codeerr = htcore.hcSqlFreeConnect(&self.hdb)
        if codeerr !=0:
            InterfaceError("hcSqlFreeConnect error %d:", codeerr)

    def cursor(self, err_to_user=False):
        """
        DB-API Connection.cursor()
        :param err_to_user:
        :return:
        """
        if DEBUG:
            err_to_user = True
        if not self._is_connected:
            raise ProgrammingError('Connection is already closed')
        else:
            return Cursor(self.hdb, err_to_user)

    def execute(self, textsql):
        """
        :param textsql: str
        :return:
        """
        cdef int hstmt = 0
        codeerr = htcore.hcSqlAllocStmt(self.hdb, &hstmt)
        if codeerr != 0:
             raise ProgrammingError("hcSqlAllocStmt error %d:", codeerr)
        codeerr = htcore.hcSqlExecDirect(hstmt, textsql.encode('cp866'))
        if codeerr != 0:
             raise ProgrammingError("hcSqlExecDirect error %d:", codeerr)
        if hstmt != 0:
            coderror = htcore.hcSqlFreeStmt(hstmt)
            if coderror != 0:
                raise ProgrammingError("hcSqlAllocStmt error %d:" % coderror)
        if DEBUG: log.debug("%r: execute(): textsql=\"%s\"" % (self, textsql))

    def begin(self, name, tables_name):
        """
        Начать транзакцию
        :param name: str
        :param tables_name:
        """
        self.execute('begin work %s table %s;' % (name, ', '.join(tables_name)))

    def commit(self, name):
        """DB-API Connection.commit()
        :param name: str
        """
        self.execute('commit work %s;' % name)

    def rollback(self, name):
        """DB-API Connection.rollback()
        :type name: str
        """
        try:
            self.execute('rollback work %s;' % name)
        except ProgrammingError as err:
            if err.error_code_hytech == -64:
                raise ProgrammingError('%r: rollback(): transaction named "%s" does not exist' % (self, name))
            else:
                raise ProgrammingError(err._message , err.error_code_hytech)

    def server_version(self):
        """
        Версия сервера Hytech
        :return: str
        """
        cdef:
            unsigned	size=20;
            unsigned cnt;
            char pValue[50]
        codeerr = htcore.hcSqlGetConnectAttr(self.hdb,
                                 HSCLI_CONN_SRV_VERS2,
                                 0,
                                 pValue,
                                 size,
                                 &cnt
                                 )

        if codeerr !=0:
            raise DatabaseError("server_version error %d:", codeerr)
        if DEBUG: log.debug("%r: server_version %s" % (self, pValue.decode('cp866')))
        return pValue.decode('cp866')

    def server_address(self):
        """
        Сетевой адрес (сервера)
        :return: str
        """
        cdef:
            unsigned cnt;
            char pValue[80]
        codeerr = htcore.hcSqlGetConnectAttr(self.hdb,
                                 HSCLI_CONN_RMTADDR,
                                 0,
                                 pValue,
                                 sizeof(pValue),
                                 &cnt
                                 )
        if codeerr !=0:
            raise DatabaseError("server_address error %d:", codeerr)
        if DEBUG: log.debug("%r: server_address() %s" % (self, pValue.decode('cp866')))
        return pValue.decode('cp866')

    def client_address(self):
        """
        Адрес (клиента)
        :return: str
        """
        cdef:
            unsigned	size=50
            unsigned cnt
            char pValue[50]

        codeerr = hcSqlGetConnectAttr(self.hdb,
                                         HSCLI_CONN_LCLADDR,
                                         0,
                                         pValue,
                                         size,
                                         &cnt
                                         )

        if codeerr !=0:
            raise DatabaseError("hcSqlGetConnectAttr error %d:", codeerr)
        return pValue.decode('cp866')

    def usersend_callback(self, uscallback):
        """
        Функция обработки пользовательских
        сообщений сервера
        :param uscallback:
        :return:
        """
        globals()['USCALLBACK'] = uscallback
        codeerr = htcore.hcSqlSetConnectAttr(self.hdb,  HSCLI_ATTR_CBK_SRVUSERSEND, &hcSqlCbkSrvUserSendT, 0)
        if codeerr !=0:
            raise DatabaseError("hcSqlSetConnectAttr error %d:", codeerr)

    def send_callback(self, scallback):
        """
        Функция обработки
        сообщений сервера
        :param scallback:
        :return:
        """
        globals()['SCALLBACK'] = scallback
        codeerr = htcore.hcSqlSetConnectAttr(self.hdb,  HSCLI_ATTR_CBK_SRVMSG, &hcSqlCbkSrvMsgT, 0)
        if codeerr !=0:
            raise DatabaseError("hcSqlSetConnectAttr error %d:", codeerr)

    def addrecords(self, table_name, pydata, cursor=None):
        """
        Пакетное добавление записей в таблицу
        :param table_name: Имя таблицы Hytech
        :param pydata: данные для загрузки [[1, '2'], [1, '3']...]
        :param cursor: Cursor
        :return:
        """
        if DEBUG: log.debug("%r: addrecords(table_name='%s')" % (self, table_name))
        cdef:
            char *pBuf
            WORD_CHAR _word
            INTR_CHAR _intr
            NMBR_CHAR _nmbr
            LONG_CHAR _long
            DWRD_CHAR _dwrd
            FLOA_CHAR _floa
            DFLT_CHAR _dflt
            # UCHAR_CHAR _uchar
            char* c_string
            char *pName # Имя таблицы
        table_name_bytes = table_name.encode('cp866')
        pName = table_name_bytes
        records_number = 0 # Количество записей таблицы в буфер
        buf_size = 0 # размер буфера
        record_size = 0 # Длина одной записи таблицы в байтах record_size
        record_pos = 0 # текущая позиция record
        write_size = 0 # общий объем данных в байтах
        textsql = 'select * from HTTBLSTRUCT("%s");' % table_name
        if not cursor:
            cursor_close = True
            cursor = self.cursor()
        else:
            cursor_close = False
        cursor.execute(textsql)
        table_struct = [row for row in cursor.fetchall()]
        fields = []
        columns_number = len(table_struct)
        for nc in range(columns_number):
            field = Field()
            field.asname = table_struct[nc][2]
            field.type = table_struct[nc][3]
            field.len = table_struct[nc][4]
            fields.append(field)
        record_size = sum([row[4] for row in table_struct])
        write_size = len(pydata) * record_size
        if write_size <= HEAPCTRL:
            buf_size = write_size
        else:
            buf_size = <long>HEAPCTRL//record_size*record_size
        pBuf = <char *> malloc(buf_size)
        buf_pos = 0
        for record_pos, row in enumerate(pydata):
            for nf, field in enumerate(fields):
                pyvalue = row[nf]
                pytype = type(pyvalue)
                if field.type > 11:
                    raise ProgrammingError('Field type error')
                if field.type  == HSCLI_ET_CHAR:
                    if pytype == str:
                        pyvalue = pyvalue.encode('cp866')
                    # elif pytype == bytes:
                    #     pyvalue
                    else:
                        raise ProgrammingError('Field type error '+str(pytype)+ ' expected string or bytes')
                    c_string = pyvalue
                    for nb in range(field.len):
                        if nb <= len(pyvalue):
                            pBuf[buf_pos] = <char>c_string[nb]
                        else:
                            # Все что больше входящей строки заполняем пробелами
                            pBuf[buf_pos] = <char>32
                        buf_pos += 1

                elif field.type == HSCLI_ET_ARRA:
                    if pytype not in [bytes, str]:
                        raise ProgrammingError('Field type error '+str(pytype)+ ' expected str or bytes')
                    sb = ''
                    if pytype == str:
                        pyvalue = pyvalue.encode('cp866')
                    f = lambda x: x if x in b'0123456789ABCDFabcdf' else 48
                    sb = bytes([f(b) for b in pyvalue])
                    corsize = (len(pyvalue) - field.len * 2)
                    if corsize > 0:
                        sb = sb[:field.len * 2]
                    elif corsize < 0:
                        sb = sb + b'0' * (corsize * (-1))
                    bytes_arr = bytes([bv for bv in binascii.a2b_hex(sb)])
                    c_string = bytes_arr
                    for nb in range(field.len):
                        pBuf[buf_pos] = <char>c_string[nb]
                        buf_pos += 1
                elif field.type == HSCLI_ET_BYTE:
                    if pytype != int:
                        raise ProgrammingError('Field type error '+str(pytype)+ ' expected int')
                    if pyvalue < 0 or pyvalue > 254:
                        raise ProgrammingError('Data value error '+str(pyvalue)+ ' does not belong to the range from 0 to 254')
                    pBuf[buf_pos] = <unsigned char>pyvalue
                    buf_pos += 1
                elif field.type == HSCLI_ET_INTR:
                    if pytype != int:
                        raise ProgrammingError('Field type error '+str(pytype)+ ' expected int')
                    if pyvalue < -32767 or pyvalue > 32767:
                        raise ProgrammingError('Data value error '+str(pyvalue)+ ' does not belong to the range from -32767 to 32767')
                    _intr.intr = <signed short>pyvalue
                    pBuf[buf_pos] = _intr.chr[0]
                    pBuf[buf_pos+1] = _intr.chr[1]
                    buf_pos += 2
                elif field.type == HSCLI_ET_WORD:
                    if pytype != int:
                        raise ProgrammingError('Field type error '+str(pytype)+ ' expected int')
                    if pyvalue < 0 or pyvalue > 65534:
                        raise ProgrammingError('Data value error '+str(pyvalue)+ ' does not belong to the range from 0 to 65534')
                    _word.wrd = <unsigned short>pyvalue
                    pBuf[buf_pos] = _word.chr[0]
                    pBuf[buf_pos+1] = _word.chr[1]
                    buf_pos += 2
                elif field.type == HSCLI_ET_DATE:
                    if pytype != datetime.date:
                        raise ProgrammingError('Field type error '+str(pytype)+ ' expected datetime.date')
                    _word.wrd = _pydate2htdate(pyvalue)
                    pBuf[buf_pos] = _word.chr[0]
                    pBuf[buf_pos+1] = _word.chr[1]
                    buf_pos += 2
                elif field.type == HSCLI_ET_NMBR:
                    if pytype != int:
                        raise ProgrammingError('Field type error '+str(pytype)+ ' expected int')
                    if pyvalue < 0 or pyvalue > 16777214:
                        raise ProgrammingError('Data value error '+str(pyvalue)+ ' does not belong to the range from 0 to 16777214')
                    _nmbr.nmbr = <unsigned int>pyvalue
                    for nb in [0, 1, 2]:
                        pBuf[buf_pos] = _nmbr.chr[nb]
                        buf_pos += 1
                elif field.type == HSCLI_ET_LONG:
                    if pytype != int:
                        raise ProgrammingError('Field type error '+str(pytype)+ ' expected int')
                    if pyvalue < -2147483647 or pyvalue > 2147483647:
                        raise ProgrammingError('Data value error '+str(pyvalue)+ ' does not belong to the range from -2147483647 to 2147483647')
                    _long.lng = <long int>pyvalue
                    for nb in range(field.len):
                        pBuf[buf_pos] = _long.chr[nb]
                        buf_pos += 1
                elif field.type == HSCLI_ET_DWRD:
                    if pytype != int:
                        raise ProgrammingError('Field type error '+str(pytype)+ ' expected int')
                    if pyvalue < 0 or pyvalue > 4294967294:
                        raise ProgrammingError('Data value error '+str(pyvalue)+ ' does not belong to the range from 0 to 4294967294')
                    _dwrd.dwrd = <unsigned long int>pyvalue
                    for nb in range(field.len):
                        pBuf[buf_pos] = _dwrd.chr[nb]
                        buf_pos += 1
                elif field.type == HSCLI_ET_FLOA:
                    if pytype != float:
                        raise ProgrammingError('Field type error '+str(pytype)+ ' expected float')
                    _floa.floa = <float>pyvalue
                    for nb in range(field.len):
                        pBuf[buf_pos] = _floa.chr[nb]
                        buf_pos += 1
                elif field.type in [HSCLI_ET_CURR, HSCLI_ET_DFLT]:
                    if pytype != float:
                        raise ProgrammingError('Field type error '+str(pytype)+ ' expected float')
                    _dflt.dflt = <double>pyvalue
                    for nb in range(field.len):
                        pBuf[buf_pos] = _dflt.chr[nb]
                        buf_pos += 1
            records_number += 1
            if  buf_pos == buf_size or record_pos+1 == len(pydata):
                coderror = hcSqlAddRecords(self.hdb,
                                             pName,
                                             <long>records_number,
                                             <unsigned>record_size,
                                             pBuf)
                records_number = 0
                buf_pos = 0


cdef void __stdcall hcSqlCbkSrvMsgT(int hdb, int is_err) with gil:
    """
    /* Функция callback  обработки текстовых сообщений сервера */
    :param hdb: int /* Идентификатор соединения */
    :param is_err: int Параметр определяет, является ли присланное сообщение сообщением об ошибке.
                    1 — прислано сообщение об ошибке,
                    0 — прислано текстовое сообщение.
    :return:
    """
    message = ''
    cdef:
        unsigned readcnt = 1
        unsigned size = 250
        char[250] pBuf
    while readcnt != 0:
        htcore.hcSqlConnReadMsg(hdb, &pBuf, size, &readcnt)
        message += pBuf[:readcnt].decode("CP866")
    if SCALLBACK:
        SCALLBACK(message)
    else:
        srvsendlog(message)


cdef void __stdcall hcSqlCbkSrvUserSendT(int hdb, int usertype) with gil:
    """
    Функция обработки пользовательских сообщений
    :param hdb: int /* Идентификатор соединения */
    :param usertype: int Тип пользовательского сообщения, определяется первым параметром SQL-функции usersend. 
    :return:
    """
    message = ''
    cdef:
        unsigned readcnt = 1
        unsigned size = 250
        char[250] pBuf
    while readcnt != 0:
        htcore.hcSqlConnReadMsg(hdb, &pBuf, size, &readcnt)
        message += pBuf[:readcnt].decode("CP866")
    if USCALLBACK:
        USCALLBACK(message, usertype)
    else:
        srvsendlog(message)


cdef class Field:
    cdef:
        public object aliasno
        public object fieldno
        public object type
        public object len
        public object off
        public object coder
        public object fname
        public object func
        public object asname
        public object key
        public object resno

    @property
    def name(self):
        if self.asname != b'':
            return self.asname.decode('cp866')
        elif self.fname != b'':
            return self.fname.decode('cp866')
        else:
            return ''

    def __str__(self):
        return self.name + ' '+str(self.type)


cdef class Cursor:
    """
    DB-API Cursor
    Cursor(err_to_user=True)
        --Включение расширенной диагностики Hytech
        --отправлять текстовые сообщения
    """

    cdef:
        int hstmt # /* идентификатор оператора */
        unsigned buf_size
        public unsigned arraysize # DB-API arraysize
        int columns_count
        public long row_count
        long row_start
        object fields
        object rows
        int open_results
        int result_contains_record
        object _retcode

    def __cinit__(self, int hdb, object err_to_user):
        """
        :type err_to_user: bool
        :param hdb: int /* Идентификатор соединения */
        :return:
        """
        cdef:
            int codeerr
            int pValue
            unsigned size
            boo
        self.arraysize = 1
        if DEBUG: log.debug("%r: __cinit__(err_to_user=%s)  " % (self, err_to_user))
        codeerr = htcore.hcSqlAllocStmt(hdb, &self.hstmt)
        if codeerr !=0:
            raise InterfaceError("hcSqlAllocStmt error %d:", codeerr)
        pValue = 1
        size = 0
        codeerr = htcore.hcSqlSetStmtAttr(self.hstmt, HSCLI_ATTR_FLD_VERBOSE, &pValue, size)
        if codeerr !=0:
            raise InterfaceError("hcSqlSetStmtAttr error %d:", codeerr)

    def __iter__(self):
        return self

    def __next__(self):
        r = self.fetchone()
        if not r:
            raise StopIteration()
        return r

    def next(self):
        return self.__next__()

    def __init__(self, hdb, err_to_user):
        if err_to_user:
            self._err_to_user()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        if self.hstmt:
            self.close()

    def __del__(self):
        if self.hstmt:
            self.close()

    cdef _reset(self):
        if self.open_results == 1:
            coderror = htcore.hcSqlCloseResults(self.hstmt)
            if coderror != 0:
                raise ProgrammingError("hcSqlCloseResults error %d:" % coderror)
        self.columns_count = 0 #/* Место для количества колонок */
        self.row_count = 0 #/* Место для количества строк */
        self.row_start = 0
        self.fields = None
        self.rows = None
        self.buf_size = 0
        self.open_results = 0
        self._retcode = None
        if DEBUG: log.debug("%r: _reset()" % self)

    def set_start_record(self, num):
        """
        установить начальную запись
        для чтения реультата в операторе
        :param num: int
        :return: None
        """
        self.row_start = num

    def get_number_records(self):
        """
        количество записей в реультате
        оператора
        :return: int
        """
        return self.row_count

    def execute(self, textsql, params=None):
        """
        DB-API Cursor.execute()
        :param textsql: str
        :param params:
        :return:
        """
        cdef:
            unsigned buffer_size #/* сколько байтов записали в буфер */
            int codeerr
            unsigned result_type
            unsigned retcode_length
            unsigned rec_size
            unsigned heapctrl = HEAPCTRL
            unsigned csize
        if params:
            sql = (textsql % params).encode('cp866')
        else:
            sql = textsql.encode('cp866')
        self._reset()
        codeerr = htcore.hcSqlExecDirect(self.hstmt, sql)
        if codeerr == -97:
            raise ProgrammingError("Cursor closed, error=%d:", codeerr)
        elif codeerr != 0:
            if DEBUG: log.error('execute(textsql="%s"' %  sql)
            if params:
                raise IntegrityError("execute() error=%d: params=[$%]", (codeerr, ', '.join(params)))
            else:
                raise ProgrammingError("execute() error %d:", codeerr)
        if DEBUG:
            log.debug('%r: execute(textsql="%s", params=%s)' % (self, textsql, params))
        codeerr = htcore.hcSqlGetStmtAttr(self.hstmt,
                                          HSCLI_STMT_SAB_TYPE,
                                          0,
                                          &result_type,
                                          sizeof(buffer_size),
                                          &buffer_size)
        if codeerr != 0:
             raise ProgrammingError("hcSqlGetStmtAttr error %d:", codeerr)
        if DEBUG:
            log.debug("Cursor.execute() result type: %d" % result_type)
        if result_type == HSCLI_RES_NONE: #/* Результата нет */
            return
        codeerr = htcore.hcSqlGetStmtAttr(self.hstmt,
                                          HSCLI_STMT_RC_SIZE,
                                          0,
                                          &retcode_length,
                                          sizeof(retcode_length),
                                          &buffer_size)
        if codeerr != 0:
             raise ProgrammingError("hcSqlGetStmtAttr error %d:", codeerr)
        if retcode_length > 0:
            self._read_retcode(retcode_length)
        self.result_contains_record = 1
        codeerr =  htcore.hcSqlRowCount(self.hstmt, &self.row_count)
        if codeerr != 0:
            raise ProgrammingError("hcSqlRowCount error %d:", codeerr)
        codeerr =  htcore.hcSqlNumResultCols(self.hstmt, &self.columns_count)
        if codeerr != 0:
            raise ProgrammingError("hcSqlNumResultCols error %d:", codeerr)
        if DEBUG:
            log.debug("Cursor.execute() row_count: %d, columns_count: %d" % (self.row_count, self.columns_count))
        if self.columns_count == HSCLI_RES_NONE:
            return
        csize = self.columns_count * 128
        col_array = <ColStruct_t *>malloc(csize)
        codeerr = htcore.hcSqlOpenResults(self.hstmt, &rec_size)
        if codeerr != 0:
            log.error("columns_count: %d" % (self.columns_count))
            raise ProgrammingError("hcSqlOpenResults error %d:", codeerr)
        self.open_results = 1
        self.buf_size = rec_size
        while self.buf_size < heapctrl:
            self.buf_size += rec_size
        codeerr = htcore.hcSqlGetStmtAttr(self.hstmt,
                                          HSCLI_STMT_DST_INFO,
                                          0,
                                          col_array,
                                          csize,
                                          &buffer_size)
        if codeerr != 0:
            raise ProgrammingError("hcSqlGetStmtAttr error %d:", codeerr)
        self.fields = []
        for nc in range(self.columns_count):
            field = Field()
            for key in col_array[nc]:
                setattr(field, key, (<object>col_array[nc])[key])
            self.fields.append(field)
        self.rows = self._read_results(buffer_size, rec_size)

    def close(self):
        """
        DB-API Cursor.close()
        """
        if self.hstmt == 0:
            raise ProgrammingError('cursor is already closed')
        if self.open_results == 1:
            coderror = htcore.hcSqlCloseResults(self.hstmt)
            if coderror != 0:
                raise ProgrammingError("hcSqlCloseResults error %d:" % coderror)
        if self.rows:
            self.rows.close()
        coderror = htcore.hcSqlFreeStmt(self.hstmt)
        if coderror != 0:
            raise ProgrammingError("hcSqlFreeStmt error %d:" % coderror)
        self.hstmt = 0

    def fetchone(self):
        """
        DB-API Cursor.fetchone()
        """
        if self.result_contains_record == 0:
            raise ProgrammingError("execute() did not produce any result set")
        if self.rows:
            try:
                return self.rows.__next__()
            except StopIteration:
                return

    def fetchmany(self, size=None):
        """
        DB-API Cursor.fetchmany()
        :param size: int
        :return:
        """
        if self.result_contains_record == 0:
            raise ProgrammingError("execute() did not produce any result set")
        if not size:
            size = self.arraysize
        return [row for num, row in enumerate(self.rows) if num < size]

    def fetchall(self):
        """
        DB-API Cursor.fetchall()
        """
        if self.result_contains_record == 0:
            raise ProgrammingError("execute() did not produce any result set")
        return [row for row in self.rows]

    def retcode(self):
        """
        код возврата при
        выполнении SQL запроса
        :return: str
        """
        return self._retcode

    @property
    def description(self):
        """
        DB-API Cursor.description
        """
        if self.fields:
            desc = collections.namedtuple('Field', ['name', 'type_code', 'display_size', 'internal_size',
                                                   'precision', 'scale', 'null_ok',])
            return [desc(*[field.name, field.type, 0, field.len, None, None,None]) for field in self.fields]

    def _read_retcode(self, retcode_length):
        cdef:
            unsigned buffer_size
            int retcode_type
            char *pBuf
            WORD_CHAR _word
            INTR_CHAR _intr
            NMBR_CHAR _nmbr
            LONG_CHAR _long
            DWRD_CHAR _dwrd
            FLOA_CHAR _floa
            DFLT_CHAR _dflt
            UCHAR_CHAR _uchar

        codeerr = htcore.hcSqlGetStmtAttr(self.hstmt,
                                          HSCLI_STMT_RC_TYPE,
                                          0,
                                          &retcode_type,
                                          sizeof(retcode_type),
                                          &buffer_size)
        if codeerr != 0:
             raise ProgrammingError("hcSqlGetStmtAttr error %d:", codeerr)
        if DEBUG:
            log.debug("retcode_type: %d, retcode_length: %d" % (retcode_type, retcode_length))
        if retcode_type == HSCLI_RES_NONE:
            return
        pBuf =  <char *> malloc(retcode_length)
        codeerr = htcore.hcSqlGetStmtAttr(self.hstmt,
                          HSCLI_STMT_RC_BODY,
                          0,
                          pBuf,
                          retcode_length,
                          &buffer_size)
        if codeerr != 0:
             raise ProgrammingError("hcSqlGetStmtAttr error %d:", codeerr)
        if retcode_type == HSCLI_ET_CHAR: # Массив символов длиной не более заданной
            try:
                self._retcode = pBuf.decode('cp866')
            except UnicodeEncodeError:
                self._retcode = pBuf
        elif retcode_type == HSCLI_ET_ARRA: # Массив байтов заданной длины
            self._retcode = binascii.b2a_hex(pBuf)
        elif retcode_type == HSCLI_ET_BYTE: # unsigned char (короткое целое)
            _uchar.chr[0] = pBuf[0]
            self._retcode = <object>_uchar.uchr
        elif retcode_type == HSCLI_ET_INTR: # signed short
            _intr.chr[0] = pBuf[0]
            _intr.chr[1] = pBuf[1]
            self._retcode = <object>_intr.intr
        elif retcode_type == HSCLI_ET_WORD: # unsigned short
            _word.chr[0] = pBuf[0]
            _word.chr[1] = pBuf[1]
            self._retcode = <object>_word.wrd
        elif retcode_type == HSCLI_ET_DATE: # Дата - unsigned short
            _word.chr[0] = pBuf[0]
            _word.chr[1] = pBuf[1]
            self._retcode = htdate2pydate(_word.wrd)
        elif retcode_type == HSCLI_ET_NMBR: # 3-х байтовое целое без знака
            for nb in range(retcode_length):
                _nmbr.chr[nb] = pBuf[nb]
            self._retcode = <object>_nmbr.nmbr
        elif retcode_type == HSCLI_ET_LONG: # long int
            for nb in range(retcode_length):
                _long.chr[nb] = pBuf[nb]
            self._retcode = <object>_long.lng
        elif retcode_type == HSCLI_ET_DWRD: # unsigned long int
            for nb in range(retcode_length):
                _dwrd.chr[nb] = pBuf[nb]
            self._retcode = <object>_dwrd.dwrd
        elif retcode_type == HSCLI_ET_FLOA: # float
            for nb in range(retcode_length):
                _floa.chr[nb] = pBuf[nb]
            self._retcode = <object>_floa.floa
        elif retcode_type in [HSCLI_ET_CURR, HSCLI_ET_DFLT]:  #Деньги (double)
            for nb in range(retcode_length):
                _dflt.chr[nb] = pBuf[nb]
            self._retcode = <object>_dflt.dflt

    def _read_results(self, unsigned buffer_size, unsigned rec_size):
        if DEBUG:
            log.debug("%r: _read_results(buffer_size=%d, rec_size=%d)" % (self, buffer_size, rec_size))
        cdef:
            unsigned readcnt = 1
            char *pBuf
            WORD_CHAR _word
            INTR_CHAR _intr
            NMBR_CHAR _nmbr
            LONG_CHAR _long
            DWRD_CHAR _dwrd
            FLOA_CHAR _floa
            DFLT_CHAR _dflt
            UCHAR_CHAR _uchar
            ColStruct_t *col_array

        pBuf =  <char *> malloc(self.buf_size)
        if not self.row_count:
            return
        while readcnt:
            codeerr = htcore.hcSqlReadResults(self.hstmt,
                                              self.row_start,
                                              pBuf,
                                              self.buf_size,
                                              &readcnt)
            if codeerr != 0:
                raise ProgrammingError("hcSqlReadResults error %d:", codeerr)
            if not readcnt:
                break
            read_size = <object>readcnt
            pos = 0
            while read_size:
                row = []
                pyvalue = None
                for field in self.fields:
                    if field.type > 11:
                        raise ProgrammingError('Field type error')
                    if field.type  == HSCLI_ET_CHAR:
                        try:
                            pyvalue = pBuf[pos: pos+field.len].decode('cp866')
                        except UnicodeEncodeError:
                            pyvalue = pBuf[pos: pos+field.len]
                    elif field.type == HSCLI_ET_ARRA:
                        pyvalue = binascii.b2a_hex(pBuf[pos: pos+field.len])
                    elif field.type == HSCLI_ET_BYTE:
                        _uchar.chr[0] = pBuf[pos]
                        pyvalue = <object>_uchar.uchr
                    elif field.type == HSCLI_ET_INTR:
                        _intr.chr[0] = pBuf[pos]
                        _intr.chr[1] = pBuf[pos + 1]
                        pyvalue = <object>_intr.intr
                    elif field.type == HSCLI_ET_WORD:
                        _word.chr[0] = pBuf[pos]
                        _word.chr[1] = pBuf[pos + 1]
                        pyvalue = <object>_word.wrd
                    elif field.type == HSCLI_ET_DATE:
                        _word.chr[0] = pBuf[pos]
                        _word.chr[1] = pBuf[pos + 1]
                        pyvalue = htdate2pydate(_word.wrd)
                    elif field.type == HSCLI_ET_NMBR:
                        for nb in range(field.len):
                            _nmbr.chr[nb] = pBuf[pos + nb]
                        pyvalue = <object>_nmbr.nmbr
                    elif field.type == HSCLI_ET_LONG:
                        for nb in range(field.len):
                            _long.chr[nb] = pBuf[pos + nb]
                        pyvalue = <object>_long.lng
                    elif field.type == HSCLI_ET_DWRD:
                        for nb in range(field.len):
                            _dwrd.chr[nb] = pBuf[pos + nb]
                        pyvalue = <object>_dwrd.dwrd
                    elif field.type == HSCLI_ET_FLOA:
                        for nb in range(field.len):
                            _floa.chr[nb] = pBuf[pos + nb]
                        pyvalue = <object>_floa.floa
                    elif field.type in [HSCLI_ET_CURR, HSCLI_ET_DFLT]:
                        for nb in range(field.len):
                            _dflt.chr[nb] = pBuf[pos + nb]
                        pyvalue = <object>_dflt.dflt

                    row.append(pyvalue)
                    pos += field.len

                self.row_start += 1
                read_size -= rec_size
                yield row

    def _err_to_user(self):
        """
        Изменение режима расширенной диагностики Hytech
        на отправлять текстовые сообщения
        :return:
        """
        textsql = b"err_to_user(1);"
        codeerr = htcore.hcSqlExecDirect(self.hstmt, textsql)
        if codeerr != 0:
             raise ProgrammingError("hcSqlExecDirec error %d:", codeerr)


#/*format hytechdb date to python date*/
PyDateTime_IMPORT
cdef object htdate2pydate(unsigned short htdate):
    if htdate == 0:
        return None
    cdef:
        unsigned	day
        unsigned	month
        unsigned	year
    hcSqlUnpackDate(htdate, &day, &month, &year)
    return PyDate_FromDate(year, month, day)


cdef unsigned short _pydate2htdate(object pydate):
    cdef:
        unsigned	day
        unsigned	month
        unsigned	year
    day = <unsigned>PyDateTime_GET_DAY(pydate)
    month = <unsigned>PyDateTime_GET_MONTH(pydate)
    year = <unsigned>PyDateTime_GET_YEAR(pydate)
    return hcSqlPackDate(day, month, year)


def pydate2htdate(pydate: datetime.date):
    """
    граница диапазона с 01-01-1900 по 31-12-2078
    :param pydate: datetime.date
    :return: int
    """
    if not datetime.date(1900, 1, 1) <= pydate <= datetime.date(2078, 12, 31):
        raise ProgrammingError("%s - does not include the date range 01-01-1900 to 31-12-2078" % pydate)
    return _pydate2htdate(pydate)

def connect(dsn, user='', passwd=''):
    if dsn is None:
        raise InterfaceError("dsn value should not be None")
    connect = Connection()
    connect.connect(dsn, user, passwd)
    return connect
