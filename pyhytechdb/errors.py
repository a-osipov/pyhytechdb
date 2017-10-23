class Error(Exception):
    def __init__(self, message, error_code_hytech=None):
        self._message = message
        self.error_code_hytech = error_code_hytech
        self.args = [message, error_code_hytech]

    def __str__(self):
        if self.error_code_hytech:
            return self._message % self.error_code_hytech
        else:
            return self._message


class InterfaceError(Error):
    pass


class DatabaseError(Error):
    pass


class InternalError(DatabaseError):
    def __init__(self):
        DatabaseError.__init__(self, 'InternalError')


class OperationalError(DatabaseError):
    pass


class ProgrammingError(DatabaseError):
    pass


class IntegrityError(DatabaseError):
    pass


class DataError(DatabaseError):
    pass


class NotSupportedError(DatabaseError):
    def __init__(self):
        DatabaseError.__init__(self, 'NotSupportedError')
