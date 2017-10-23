#include "c_hscli.h"
#include <windows.h>
#include <stdio.h>
#include<string.h>

#define	HSCLI_ATTR_CBK_SRVMSG		1100	/* [conn] Функция обработки сообщений сервера (hcSqlCbkSrvMsgT*) */
#define	HSCLI_ATTR_CBK_SRVUSERSEND	1101	/* [conn] Функция обработки пользовательских сообщений сервера (hcSqlCbkSrvUserSendT*) */

int hcsqlinit(){
    hcERR err;
    hinstLib = LoadLibrary("hscli.dll");
    if (hinstLib == NULL){
         err = 3001;
         return err;
         };
    hcSqlInit = (HCSQLINIT)GetProcAddress(hinstLib, "hcSqlInit");; /* Инициализировать клиентскую часть */
    hcSqlDone = (HCSQLDONE)GetProcAddress(hinstLib, "hcSqlDone"); /* Завершить работу */
    hcSqlAllocConnect = (HCSQLALLOCCONNECT)GetProcAddress(hinstLib, "hcSqlAllocConnect"); /* Создать соединение */
    hcSqlDisconnect = (HCSQLDISCONNECT)GetProcAddress(hinstLib, "hcSqlDisconnect");  /* разрывает связь с сервером БД*/
    hcSqlFreeConnect = (HCSQLFREECONNECT)GetProcAddress(hinstLib, "hcSqlFreeConnect"); /*освобождает ресурсы, выделенные соединению*/
    hcSqlConnect = (HCSQLCONNECT)GetProcAddress(hinstLib, "hcSqlConnect"); /* Установить связь с сервером БД */
    hcSqlGetConnectAttr = (HCSQLGETCONNECTATTR)GetProcAddress(hinstLib, "hcSqlGetConnectAttr"); /* Получить информацию об соединении */
    hcSqlSetConnectAttr = (HCSQLSETCONNECTATTR)GetProcAddress(hinstLib, "hcSqlSetConnectAttr"); /* Изменение параметров соединения */
    hcSqlAllocStmt = (HCSQLALLOCSTMT)GetProcAddress(hinstLib, "hcSqlAllocStmt"); /* Создать оператор */
    hcSqlSetStmtAttr = (HCSQLSETSTMTATTR)GetProcAddress(hinstLib, "hcSqlSetStmtAttr"); /* Изменение параметров оператора */
    hcSqlExecDirect = (HCSQLEXECDIRECT)GetProcAddress(hinstLib, "hcSqlExecDirect"); /* Странслировать и выполнить SQL-скрипт */
    hcSqlExecDirectAsync = (HCSQLEXECDIRECTASYNC)GetProcAddress(hinstLib, "hcSqlExecDirectAsync"); /* Странслировать и выполнить SQL-скрипт */
    hcSqlExecDirectQuery = (HCSQLEXECDIRECTQUERY)GetProcAddress(hinstLib, "hcSqlExecDirectQuery"); /* Получить результат выполнения запроса */
    hcSqlConnReadMsg = (HCSQLCONNREADMSG)GetProcAddress(hinstLib, "hcSqlConnReadMsg"); /* Чтение данных сообщения */
    hcSqlGetStmtAttr = (HCSQLGETSTMTATTR)GetProcAddress(hinstLib, "hcSqlGetStmtAttr"); /* hcSqlGetStmtAttr — Получить информацию об операторе */
    hcSqlNumResultCols = (HCSQLNUMRESULTCOLS)GetProcAddress(hinstLib, "hcSqlNumResultCols"); /* возвращает количество колонок в результате. */
    hcSqlRowCount = (HCSQLROWCOUNT)GetProcAddress(hinstLib, "hcSqlRowCount"); /* возвращает количество строк в результате, который хранится в указанном операторе. */
    /* Открыть результаты для чтения. Читаются данные, отобранные
    * оператором select с учетом тех выражений, которые в нем заданы. */
    hcSqlOpenResults = (HCSQLOPENRESULTS)GetProcAddress(hinstLib, "hcSqlOpenResults");
    /* Чтение результатов с указанной позиции */
    hcSqlReadResults = (HCSQLREADRESULTS)GetProcAddress(hinstLib, "hcSqlReadResults");
    /* Закрыть доступ к результатам ОПЕРАТОРА   */
    hcSqlCloseResults = (HCSQLCLOSERESULTS)GetProcAddress(hinstLib, "hcSqlCloseResults");
    /* Закрыть оператор */
    hcSqlFreeStmt = (HCSQLFREESTMT)GetProcAddress(hinstLib, "hcSqlFreeStmt");
    /***************************************************************
	"Очень странные" функции
    ***************************************************************/
    //* Пакетное добавление */
    hcSqlAddRecords = (HCSQLADDRECORDS)GetProcAddress(hinstLib, "hcSqlAddRecords");

    /***************************************************************
	Внутреннее представление данных
     ***************************************************************/
    /* Упаковка даты */
    /* 0 - неправильная дата */
    hcSqlPackDate = (HCSQLPACKDATE)GetProcAddress(hinstLib, "hcSqlPackDate");
    /* Распаковка даты */
    hcSqlUnpackDate = (HCSQLUNPACKDATE)GetProcAddress(hinstLib, "hcSqlUnpackDate");

    err = hcSqlInit(0);
        return err;
};

/* Освобождаем  "hscli.dll" */
int hcsqlfree(){
    BOOL fFreeResult;
    fFreeResult = FreeLibrary(hinstLib);
    return 0;
};

