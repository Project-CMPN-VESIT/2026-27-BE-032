import sys, os
sys.path.insert(0, '.')
from backend.services.opencv_foot_service import analyze_foot_opencv

cases = [
    ('original_uploaded.jpg',                              'Healthy (real mobile)'),
    ('uploaded_debug.jpg',                                 'Healthy (debug)'),
    ('dataset/DFU/Patches/Normal(Healthy skin)/1.jpg',    'Normal dataset'),
    ('dataset/DFU/Patches/Abnormal(Ulcer)/1.jpg',         'Ulcer dataset 1'),
    ('dataset/DFU/Patches/Abnormal(Ulcer)/105.jpg',       'Ulcer dataset 105'),
]

for path, label in cases:
    if os.path.exists(path):
        res = analyze_foot_opencv(path)
        print(label, '->', res['prediction'])
    else:
        print(label, '-> FILE NOT FOUND:', path)
