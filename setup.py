from setuptools import setup

setup(
    name='pixamo',
    version='0.1',
    description='Animate pixel-art characters with ease!',
    url='https://github.com/InfiniteCoder01/pixamo',
    author='InfiniteCoder01',
    author_email='info@infinitecoder.org',
    license='MIT',
    packages=['pixamo'],
    entry_points = {
        'console_scripts': ['pixamo=pixamo:main'],
    },
    zip_safe=False
)
