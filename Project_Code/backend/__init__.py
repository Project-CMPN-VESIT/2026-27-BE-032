"""DiabeticAI backend package."""
import os
import sys
from pathlib import Path

# Ensure backend package parent is in sys.path
_pkg_dir = Path(__file__).resolve().parent
_parent_dir = _pkg_dir.parent
if str(_parent_dir) not in sys.path:
    sys.path.insert(0, str(_parent_dir))
if str(_pkg_dir) not in sys.path:
    sys.path.insert(0, str(_pkg_dir))

# Automatically ensure writable cache directories for Keras and Matplotlib
_pkg_dir = Path(__file__).resolve().parent
_keras_cache = _pkg_dir / ".keras_cache"
_keras_cache.mkdir(exist_ok=True, parents=True)
os.environ.setdefault("KERAS_HOME", str(_keras_cache))

_mpl_cache = _pkg_dir / ".mpl_cache"
_mpl_cache.mkdir(exist_ok=True, parents=True)
os.environ.setdefault("MPLCONFIGDIR", str(_mpl_cache))
