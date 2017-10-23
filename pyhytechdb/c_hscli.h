#include <windows.h>

typedef int hcERR;

static HINSTANCE hinstLib;
/* Инициализировать клиентскую часть */
typedef hcERR (__stdcall *HCSQLINIT)(int x);
static HCSQLINIT hcSqlInit;
hcERR hcsqlinit();
/* Завершить работу */
typedef hcERR (__stdcall *HCSQLDONE)();
HCSQLDONE hcSqlDone;
/* Освобождаем  "hscli.dll" */
int hcsqlfree();
/* Создать соединение */
typedef hcERR (__stdcall *HCSQLALLOCCONNECT)(int *x);
HCSQLALLOCCONNECT hcSqlAllocConnect;
/* разрывает связь с сервером БД*/
typedef hcERR (__stdcall *HCSQLDISCONNECT)(int *x);
HCSQLDISCONNECT hcSqlDisconnect;
/* Освободить соединение */
typedef hcERR (__stdcall *HCSQLFREECONNECT)(int *x);
HCSQLFREECONNECT hcSqlFreeConnect;
/* Установить связь с сервером БД */
typedef hcERR (__stdcall *HCSQLCONNECT)(int h, char s[80], char u[80], char p[80]);
HCSQLCONNECT hcSqlConnect;
/* Получить информацию об соединении */
typedef hcERR (__stdcall *HCSQLGETCONNECTATTR)(int hdb,		/* Идентификатор соединения */
                                              unsigned	option,		/* Режим */
                                              int		pos,		/* Позиция */
                                              char		*pValue,	/* Буфер для значения */
                                              unsigned	size,		/* и его размер */
                                              unsigned	*cnt		/* сколько байтов записали в буфер */
                                              );
HCSQLGETCONNECTATTR hcSqlGetConnectAttr;
/* Изменение параметров соединения */
typedef hcERR (__stdcall *HCSQLSETCONNECTATTR)(
  int hdb,		/* Идентификатор соединения */
  unsigned	option,		/* Режим */
  void		*pValue,	/* Значение (int/long) или буфер значения */
  unsigned	size		/* Размер значения в байтах или 0, если передаётся int/long */
);
HCSQLSETCONNECTATTR hcSqlSetConnectAttr;
/* Создать оператор */
typedef hcERR (__stdcall *HCSQLALLOCSTMT)(
                                          int hdb,		/* Идентификатор соединения */
                                          int *p);      /* Место для номера оператора */
HCSQLALLOCSTMT hcSqlAllocStmt;

/* Изменение параметров оператора */
typedef hcERR (__stdcall *HCSQLSETSTMTATTR)(
                                          int hStmt,		/* Идентификатор оператора */
                                          unsigned	option,		/* Режим */
                                          void		*pValue,	/* Значение (int/long) или буфер значения */
                                          unsigned	size);
HCSQLSETSTMTATTR hcSqlSetStmtAttr;

/* Странслировать и выполнить SQL-скрипт */
typedef hcERR (__stdcall *HCSQLEXECDIRECT)(int hStmt, const char	*pSql);
HCSQLEXECDIRECT hcSqlExecDirect;

/* Странслировать и выполнить SQL-скрипт асинхронно*/
typedef hcERR (__stdcall *HCSQLEXECDIRECTASYNC)(int hStmt, const char	*pSql);
HCSQLEXECDIRECTASYNC hcSqlExecDirectAsync;

/* Получить результат выполнения запроса */
typedef hcERR (__stdcall *HCSQLEXECDIRECTQUERY)(int hStmt);
HCSQLEXECDIRECTQUERY hcSqlExecDirectQuery;

/* hcSqlGetStmtAttr — Получить информацию об операторе */
typedef hcERR (__stdcall *HCSQLGETSTMTATTR)(  int	h,		/* Идентификатор оператора */
                      unsigned	option,		/* Режим */
                      int		pos,		/* Позиция */
                      void		*pValue,	/* Буфер для значения */
                      unsigned	size,		/* и его размер */
                      unsigned	*cnt);
HCSQLGETSTMTATTR hcSqlGetStmtAttr;

/*hcSqlNumResultCols возвращает количество колонок в результате. */
typedef hcERR (__stdcall *HCSQLNUMRESULTCOLS)(
                  int hStmt,		/* Номер оператора */
                  int		*pCol);		/* Место для количества колонок */
HCSQLNUMRESULTCOLS hcSqlNumResultCols;

/*hcSqlRowCount возвращает количество строк в результате, который хранится в указанном операторе.*/
typedef hcERR (__stdcall *HCSQLROWCOUNT)(
                  int hStmt,		/* Номер оператора */
                  long	*pCnt);		/* Место для количества строк */
HCSQLROWCOUNT hcSqlRowCount;

/* Открыть результаты для чтения. Читаются данные, отобранные
 * оператором select с учетом тех выражений, которые в нем заданы. */
 typedef hcERR (__stdcall *HCSQLOPENRESULTS)(
              int hStmt,		/* Оператор с результатами */
              unsigned 	*pRecSize); 	/* Сюда запишется размер записи */
HCSQLOPENRESULTS hcSqlOpenResults;

/* Чтение результатов с указанной позиции */
typedef hcERR (__stdcall *HCSQLREADRESULTS)(
  int hStmt,		/* Оператор с результатами */
  long	gStart,		/* С какой записи начинаем читать */
  void		*pBuf,		/* Адрес буфера для результатов */
  unsigned 	wBufSize, 	/* Размер буфера этого буфера */
  unsigned	*cnt);    	/* Сколько прочитали */
HCSQLREADRESULTS hcSqlReadResults;

/* Закрыть доступ к результатам ОПЕРАТОРА   */
typedef hcERR (__stdcall *HCSQLCLOSERESULTS)(int hStmt);
HCSQLCLOSERESULTS hcSqlCloseResults;

/* Закрыть оператор */
typedef hcERR (__stdcall *HCSQLFREESTMT)(int hStmt);
HCSQLFREESTMT hcSqlFreeStmt;

/* Чтение данных сообщения */
typedef hcERR (__stdcall *HCSQLCONNREADMSG)(
                      int	hdb,		/* Идентификатор соединения */
                      void		*buf,		/* Адрес буфер записи */
                      unsigned 	sz,             /* Размер буфера */
                      unsigned	*cnt);
HCSQLCONNREADMSG hcSqlConnReadMsg;

//* Пакетное добавление */
typedef hcERR (__stdcall *HCSQLADDRECORDS)(int hdb,		/* Идентификатор соединения */
  const char	*pName,		/* Краткое имя таблицы */
  long	gRecCount,	/* Количество записей */
  unsigned	wRecSize,	/* Размер записи */
  const void	*pBuf);		/* Адрес буфера с телами записей */
 HCSQLADDRECORDS hcSqlAddRecords;

 /* Упаковка даты */
 /* 0 - неправильная дата */
 typedef unsigned short (__stdcall *HCSQLPACKDATE)(
                  unsigned	day,		/* День месяца (1-31) */
                  unsigned	month,		/* Месяц (1-12) */
                  unsigned	year);		/* Год (1900-2078) */
 HCSQLPACKDATE hcSqlPackDate;

 /* Распаковка даты */
 typedef hcERR (__stdcall *HCSQLUNPACKDATE)(
  unsigned short htdate,
  unsigned	*day,
  unsigned	*month,
  unsigned	*year);
 HCSQLUNPACKDATE hcSqlUnpackDate;



