cdef extern from "datetime.h":
    void PyDateTime_IMPORT()
    object PyDate_FromDate(int year, int month, int day)
    ctypedef extern class datetime.date[object PyDateTime_Date]:
        pass
    ctypedef struct PyDateTime_Date:
        pass
    # Getters for date and datetime (C macros).
    int PyDateTime_GET_YEAR(object o)
    int PyDateTime_GET_MONTH(object o)
    int PyDateTime_GET_DAY(object o)


cdef extern from "c_hscli.h":
    int hcsqlinit()
    int hcsqlfree()
    int (__stdcall *hcSqlDone)()
    # /* Создать соединение */
    int (__stdcall *hcSqlAllocConnect)(int *hdb)
    #/* разрывает связь с сервером БД*/
    int (__stdcall *hcSqlDisconnect)(int *x);
    # /* Освободить соединение */
    int (__stdcall *hcSqlFreeConnect)(int *hdb)
    # /* Установить связь с сервером БД */
    int (__stdcall *hcSqlConnect)(   int hdb,
                        char server[80],
                        char user[80],
                        char password[80])
    int (__stdcall *hcSqlAllocStmt)(int hdb, int *p)
    # /* Получить информацию об соединении */
    int (__stdcall *hcSqlGetConnectAttr)(int hdb, unsigned	option,	int pos, char *pValue, unsigned	size, unsigned *cnt)
    # /* Изменение параметров оператора */
    int (__stdcall *hcSqlSetStmtAttr)(int hStmt,  unsigned option, void *pValue, unsigned size)
    # /* Странслировать и выполнить SQL-скрипт */
    int (__stdcall *hcSqlExecDirect)(int hStmt, const char	*pSql)
    # /* Странслировать и выполнить SQL-скрипт асинхронно*/
    int (__stdcall *hcSqlExecDirectAsync)(int hStmt, const char	*pSql)
    #/* Получить результат выполнения запроса */
    int (__stdcall *hcSqlExecDirectQuery)(int hStmt)
    #* hcSqlGetStmtAttr — Получить информацию об операторе *
    int (__stdcall *hcSqlGetStmtAttr)(int h, unsigned option, int pos, void *pValue, unsigned size, unsigned *cnt);
    #*hcSqlNumResultCols возвращает количество колонок в результате. */
    int (__stdcall *hcSqlNumResultCols)(int	h, int	*pCol);
    #*hcSqlRowCount возвращает количество строк в результате, который хранится в указанном операторе.*/
    int (__stdcall *hcSqlRowCount)(int h, long *pCnt);
    #/* Открыть результаты для чтения. Читаются данные, отобранные
    #* оператором select с учетом тех выражений, которые в нем заданы. */
    int (__stdcall *hcSqlOpenResults)(int hStmt, unsigned 	*pRecSize)
    #/* Чтение результатов с указанной позиции */
    int (__stdcall *hcSqlReadResults)(int hStmt, long gStart, void *pBuf, unsigned 	wBufSize, unsigned	*cnt)
    #/* Изменение параметров соединения */
    int (__stdcall *hcSqlSetConnectAttr)(int hdb,  unsigned	option, void *pValue, unsigned	size)
    #/* Изменение параметров оператора */
    int  (__stdcall *hcSqlSetStmtAttr)(int hStmt, unsigned	option, void *pValue, unsigned size)
    #/* Чтение данных сообщения */
    int (__stdcall *hcSqlConnReadMsg)(int hdb, void *buf, unsigned sz, unsigned *cnt)
    #/* Закрыть доступ к результатам ОПЕРАТОРА   */
    int (__stdcall *hcSqlCloseResults)(int hStmt)
    # /* Закрыть оператор */
    int (__stdcall *hcSqlFreeStmt)(int hStmt)
    # //* Пакетное добавление */
    int (__stdcall *hcSqlAddRecords)(int hdb, char *pName, long gRecCount, unsigned wRecSize, void *pBuf)
    # /* Упаковка даты */
    int (__stdcall *hcSqlPackDate)(unsigned	day, unsigned	month, unsigned	year);
    # /* Распаковка даты */
    int (__stdcall *hcSqlUnpackDate)( unsigned short htdate, unsigned *day, unsigned *month, unsigned *year);


cdef struct ColStruct:
    int aliasno
    int fieldno
    int type
    unsigned len
    unsigned off
    char[32] coder
    char[32] fname
    int func
    char[32] asname
    int key
    int resno


ctypedef ColStruct ColStruct_t
ctypedef unsigned char ubyte

cdef union INTR_CHAR:
    signed short intr
    char[2] chr

cdef union WORD_CHAR:
    unsigned short wrd
    char[2] chr

cdef union NMBR_CHAR:
    unsigned int nmbr
    char[4] chr

cdef union LONG_CHAR:
    long int lng
    char[4] chr

cdef union DWRD_CHAR:
    unsigned long int dwrd
    char[4] chr

cdef union FLOA_CHAR:
    float floa
    char[4] chr

cdef union DFLT_CHAR:
    double dflt
    char[8] chr

cdef union QINT_CHAR:
    long long qint
    char[8] chr

cdef union UCHAR_CHAR:
    unsigned char uchr
    char[1] chr

