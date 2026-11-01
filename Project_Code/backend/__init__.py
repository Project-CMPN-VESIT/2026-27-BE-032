"""DiabeticAI backend package."""
import os
from pathlib import Path

# Automatically ensure writable cache directories for Keras and Matplotlib
_pkg_dir = Path(__file__).resolve().parent
_keras_cache = _pkg_dir / ".keras_cache"
_keras_cache.mkdir(exist_ok=True, parents=True)
os.environ.setdefault("KERAS_HOME", str(_keras_cache))

_mpl_cache = _pkg_dir / ".mpl_cache"
_mpl_cache.mkdir(exist_ok=True, parents=True)
os.environ.setdefault("MPLCONFIGDIR", str(_mpl_cache))
