import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('updater', Path(__file__).parents[1] / 'update_iphone.py')
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class UpdateTests(unittest.TestCase):
    def test_only_fast_forward_histories_are_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            def git(*args):
                return subprocess.run(['/usr/bin/git', *args], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()
            git('init'); git('config', 'user.name', 'Test'); git('config', 'user.email', 'test@example.invalid')
            git('commit', '--allow-empty', '-m', 'base'); base = git('rev-parse', 'HEAD')
            git('commit', '--allow-empty', '-m', 'local'); local = git('rev-parse', 'HEAD')
            self.assertEqual(updater.select_commit(repo, base, local), local)
            self.assertEqual(updater.select_commit(repo, local, base), local)
            git('checkout', '--detach', base)
            git('commit', '--allow-empty', '-m', 'remote'); remote = git('rev-parse', 'HEAD')
            with self.assertRaisesRegex(RuntimeError, 'divergiram'):
                updater.select_commit(repo, local, remote)

    def test_documentation_only_does_not_rebuild_the_app(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            def git(*args):
                return subprocess.run(['/usr/bin/git', *args], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()
            git('init'); git('config', 'user.name', 'Test'); git('config', 'user.email', 'test@example.invalid')
            (repo / 'App').mkdir(); (repo / 'App/main.swift').write_text('old')
            git('add', '.'); git('commit', '-m', 'app'); base = git('rev-parse', 'HEAD')
            (repo / 'README.md').write_text('documentation')
            git('add', '.'); git('commit', '-m', 'docs'); docs = git('rev-parse', 'HEAD')
            self.assertFalse(updater.code_changed(repo, base, docs))
            (repo / 'App/main.swift').write_text('new')
            git('add', '.'); git('commit', '-m', 'code'); code = git('rev-parse', 'HEAD')
            self.assertTrue(updater.code_changed(repo, docs, code))

    def test_running_app_is_not_replaced_and_state_is_preserved(self):
        state = {'installedCommit': 'old', 'expiresAt': 0}
        with patch.object(updater, 'phone_json', return_value={'deviceProperties': {'ddiServicesAvailable': True}}), \
             patch.object(updater, 'app_running', return_value=True), patch.object(updater, 'run') as commands:
            result = updater.install({}, Path('.'), 'new', state)
        self.assertIn('feche', result)
        self.assertEqual(state['installedCommit'], 'old')
        commands.assert_not_called()

    def test_failed_build_never_marks_new_commit_as_installed(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(updater, 'ROOT', Path(directory)), \
             patch.object(updater, 'phone_json', return_value={'deviceProperties': {'ddiServicesAvailable': True}}), \
             patch.object(updater, 'app_running', return_value=False), patch.object(updater, 'run'), \
             patch.object(updater.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'xcodebuild')):
            state = {'installedCommit': 'old', 'expiresAt': 0}
            with self.assertRaises(subprocess.CalledProcessError):
                updater.install({'device': 'test', 'team': 'test'}, Path('.'), 'new', state)
            self.assertEqual(state['installedCommit'], 'old')
            self.assertEqual(state['failures'], 1)
            saved = json.loads((Path(directory) / 'state.json').read_text())
            self.assertEqual(saved['installedCommit'], 'old')

    def test_three_failures_pause_the_same_commit(self):
        state = {'failedCommit': 'new', 'failures': 3}
        with patch.object(updater, 'phone_json') as phone:
            self.assertIn('Pausado', updater.install({}, Path('.'), 'new', state))
            phone.assert_not_called()


if __name__ == '__main__':
    unittest.main()
