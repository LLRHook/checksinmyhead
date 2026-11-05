"""Run an existing unittest CLI once, retaining methods and subtest multiplicity."""
import json
import os
from pathlib import Path
import runpy
import sys
import unittest


class Result(unittest.TextTestResult):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.cases = []
        self.started = []
        self.active = {}
        self.status = {}
        self.occurrences = {}

    def startTest(self, test):
        super().startTest(test)
        runner_id = test.id()
        self.occurrences[runner_id] = self.occurrences.get(runner_id, 0) + 1
        ident = runner_id + '/invocation:' + str(self.occurrences[runner_id])
        self.active[test] = ident
        self.started.append(ident)
        self.status[test] = 'pass'

    def record(self, test, ident, status):
        family = '.'.join(test.id().split('.')[-2:])
        self.cases.append({'id': ident, 'family': family, 'status': status})

    def stopTest(self, test):
        self.record(test, self.active.pop(test), self.status.pop(test))
        super().stopTest(test)

    def addFailure(self, test, err):
        super().addFailure(test, err); self.status[test] = 'fail'

    def addError(self, test, err):
        super().addError(test, err); self.status[test] = 'error'
        # Module/class setup errors have no startTest/stopTest pair.
        if test not in self.active:
            self.record(test, test.id(), 'error')

    def addSkip(self, test, reason):
        super().addSkip(test, reason); self.status[test] = 'skip'
        if test not in self.active:
            self.record(test, test.id(), 'skip')

    def addExpectedFailure(self, test, err):
        super().addExpectedFailure(test, err); self.status[test] = 'expected-failure'

    def addUnexpectedSuccess(self, test):
        super().addUnexpectedSuccess(test); self.status[test] = 'unexpected-success'

    def addSubTest(self, test, subtest, err):
        super().addSubTest(test, subtest, err)
        # The sequence distinguishes repeated identical subtest display IDs.
        ident = self.active[test] + '/subtest:' + str(len(self.cases)) + ':' + subtest.id()
        self.record(test, ident, 'pass' if err is None else 'fail')
        if err is not None:
            self.status[test] = 'fail'


class Runner(unittest.TextTestRunner):
    resultclass = Result

    def run(self, test):
        result = super().run(test)
        report = {'complete': not result.active and not result.shouldStop,
                  'success': result.wasSuccessful(), 'tests_run': result.testsRun,
                  'started': result.started, 'cases': result.cases}
        Path(os.environ['CASE_REPORT']).write_text(json.dumps(report) + '\n')
        return result


if __name__ == '__main__':
    script = Path(sys.argv[1]).resolve()
    original = unittest.main
    def main(*args, **kwargs):
        kwargs['testRunner'] = Runner
        return original(*args, **kwargs)
    unittest.main = main
    sys.argv = [str(script)] + sys.argv[2:]
    sys.path.insert(0, str(script.parent))
    runpy.run_path(str(script), run_name='__main__')
