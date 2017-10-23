import datetime
import binascii
from pyhytechdb.tests.base import *
from pyhytechdb.errors import *
from pyhytechdb import pydate2htdate, Date


def test_callback(message):
    print('test_callback()', message)

def test_user_callback(message, usertype):
    print('test_user_callback(): message="%s": usertype=%d' % (message, usertype))

class TestBasic(TestBase):
    def setUp(self):
        TestBase.setUp(self)
        textsql = '''
                    drop  table "foo"; 
                    create table  "foo"  (
                                   CHAR_ char(20) ,
                                   ARRAY_ array(6),
                                   BYTE_ byte,
                                   INT_ int,
                                   WORD_ word,
                                   DATE_ date,
                                   NMBR_ number,
                                   LONG_ long,
                                   DWORD_ dword,
                                   FLOAT_ float,
                                   DOUBLE_ double
                                   );'''
        self.connection.execute(textsql)

    def test_basic(self):
        conn = self.connection
        print('Hytech server version - %s' % conn.server_version())
        print('Hytech server address - %s' % conn.server_address())
        print('Client address - %s' % conn.client_address())
        with conn.cursor() as cur:
            cur.execute("select * from foo;")
            self.assertEqual(cur.fetchone(), None)

        with conn.cursor() as cur:
            cur.execute("select CHAR_ as alias_name from foo;")
            self.assertEqual(cur.description[0][0], 'alias_name')

        conn.execute("insert into foo(CHAR_, INT_, WORD_, DATE_) values ('Hello world!', 25, 58, %s);" % pydate2htdate(Date(2010, 11, 12)))
        conn.execute(
            "insert into foo(LONG_, BYTE_,FLOAT_, WORD_, DATE_) values (12555, '0055502', 5/4, 58,'$12-11-2010');")
        conn.execute(
            "insert into foo(NMBR_, DWORD_, DOUBLE_, CHAR_,  WORD_, DATE_) values (33, 55, 5.0, 'Hello!', 85, '$12-11-2010');")

        with conn.cursor() as cur:
            conn.begin('test_ta', ['foo'])
            cur.execute("""insert into foo(NMBR_, DWORD_, DOUBLE_, CHAR_,  WORD_, DATE_) 
                           values (33, 55, 5.0, 'blablabla',85,'$12-11-2017');""")
            conn.rollback('test_ta')
            cur.execute("fix all; select CHAR_ from foo where CHAR_ = 'blablabla          ';")
            self.assertEqual(cur.fetchone(), None)

        with conn.cursor() as cur:
            conn.begin('test_ta', ['foo'])
            cur.execute("""insert into foo(NMBR_, DWORD_, DOUBLE_, CHAR_,  WORD_, DATE_) 
                           values (33, 55, 5.0, 'blablabla',85,'$12-11-2017');
                           """)
            conn.commit('test_ta')
            cur.execute("fix all; select CHAR_ from foo where CHAR_ = 'blablabla             ';")

            self.assertEqual(cur.fetchone()[0].strip(), 'blablabla')

        with conn.cursor() as cur:
            cur.execute("select * from foo where CHAR_='%s';", ("blablabla             ",))
            self.assertEqual(len(cur.fetchall()), 1)
            self.assertEqual(cur.row_count, 1)
            cur.execute("select * from foo;")
            self.assertEqual(len(cur.fetchall()), 4)
            self.assertEqual(cur.row_count, 4)

        with conn.cursor() as cur:
            cur.execute("select * from foo;")
            for num in range(4):
                assert not cur.fetchone() is None
            assert cur.fetchone() is None

        with conn.cursor() as cur:
            cur.execute("select * from foo;")
            self.assertEqual(len(cur.fetchmany(2)), 2)

        with conn.cursor() as cur:
            conn.execute(
                "insert into foo(LONG_, BYTE_,FLOAT_, WORD_, DATE_) values (12555, '0055502', 5/4, 58, '$12-11-2010');")
            self.assertRaises(ProgrammingError, cur.fetchone)
            self.assertRaises(ProgrammingError, cur.fetchmany)
            self.assertRaises(ProgrammingError, cur.fetchall)

        with conn.cursor() as cur:
            try:
                cur.execute("bad sql")
            except ProgrammingError as err:
                self.assertEqual(err.error_code_hytech, -1030)

        with conn.cursor() as cur:
            cur.execute("select * from foo;")
            self.assertEqual(['CHAR_', 'ARRAY_', 'BYTE_', 'INT_', 'WORD_', 'DATE_', 'NMBR_',
                              'LONG_', 'DWORD_', 'FLOAT_', 'DOUBLE_'],
                             [d[0] for d in cur.description])
            self.assertEqual(['Hello world!', '', 'Hello!', 'blablabla'], [row[0].strip() for row in cur.fetchall()])

        with conn.cursor() as cur:
            cur.execute("select * from foo;")
            rows = [row for row in cur]
            self.assertEqual(rows[2][:3], ['Hello!              ', b'000000000000', 0])

        with conn.cursor() as cur:
            cur.execute("select * from foo;")
            for row in cur:
                row[0]

    def test_retcode(self):
        retvalues = {"'Hello!'": 'Hello!',
                     'array("852159",4)': b'852159',
                     'byte(15)': 15,
                     'int(34)': 34,
                     'word(159)': 159,
                     'date("02-12-2017")': datetime.date(2017, 12, 2),
                     'number(357)': 357,
                     'long(654)': 654,
                     'dword(789)': 789,
                     'float(1000)': 1000.0,
                     'currency(1000)': 1000.0,
                     'double(1000)': 1000.0,
                     }
        for key, res in retvalues.items():
            with self.connection.cursor() as cur:
                cur.execute('retcode(%s);' % key)
                self.assertEqual(cur.retcode(), res)

    def test_addrecords(self):
        conn = self.connection
        data = [
            ['Access', '0.84598', 1, 44, 1592, datetime.date.today(), 78899, 154, 11, 100.0, 1000.0],
            ['currency', '0.84736', 2, 44, 1592, datetime.date.today(), 78899, 155, 11, 100.0, 1000.0],
            ['exchange', '0.84883', 3, 44, 1592, datetime.date.today(), 78899, 156, 11, 100.0, 1000.0],
            ['rates', '0.84610', 4, 44, 1592, datetime.date.today(), 78899, 157, 11, 100.0, 1000.0],
            ['back', '0.84746', 5, 44, 1592, datetime.date.today(), 78899, 159, 11, 100.0, 1000.0],
            ['to', '0.84893', 6, 44, 1592, datetime.date.today(), 78899, 160, 11, 100.0, 1000.0],
            ['January', '0.84746DdddddddD', 7, 44, 1592, datetime.date.today(), 78899, 17, 11, 100.0, 1000.0],
        ]
        textsql = '''
                    drop  table "_tmp_"; 
                    create global temporary table  "_tmp_"  (
                                   CHAR_ char(20) ,
                                   ARRAY_ array(6),
                                   BYTE_ byte,
                                   INT_ int,
                                   WORD_ word,
                                   DATE_ date,
                                   NMBR_ number,
                                   LONG_ long,
                                   DWORD_ dword,
                                   FLOAT_ float,
                                   DOUBLE_ double
                                   );'''
        conn.execute(textsql)
        conn.addrecords("_tmp_", data)

        with conn.cursor() as cur:
            cur.execute("select * from _tmp_;")
            self.assertEqual(cur.fetchone(), ['Access              ', b'008459800000', 1, 44,
                                              1592, datetime.date.today(),
                                              78899, 154, 11, 100.0, 1000.0])

    def test_pydate2htdate(self):
        self.assertEqual(pydate2htdate(datetime.date(2017, 12, 2)), 43070)
        self.assertRaises(ProgrammingError, pydate2htdate, datetime.date(1800, 1, 2))
        self.assertRaises(ProgrammingError, pydate2htdate, datetime.date(2079, 1, 1))

    def test_send_callback(self):
        conn = self.connection
        conn.send_callback(test_callback)
        conn.usersend_callback(test_user_callback)
        with conn.cursor(err_to_user=True) as cur:
            try:
                cur.execute("bad sql")
            except ProgrammingError as err:
                self.assertEqual(err.error_code_hytech, -1030)
            cur.execute("usersend(159, htFormat('Hello user - %s!', current_user));")


    def tearDown(self):
        TestBase.tearDown(self)
        self.connection.execute("drop table foo;")
