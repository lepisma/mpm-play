from setuptools import find_packages, setup

with open("README.org") as readme_file:
    readme = readme_file.read()

project_url = "https://github.com/lepisma/mpm-play"

setup(
    name="mpm-play",
    version="0.1.0",
    description="Player for mpm",
    long_description=readme,
    author="Abhinav Tushar",
    author_email="abhinav.tushar.vs@gmail.com",
    url=project_url,
    install_requires=[
        "dataset",
        "docopt",
        "colorama",
        "pyyaml",
        "pafy",
        "hy==0.13.0",
        "mpm",
        "python-vlc"
    ],
    keywords="",
    packages=find_packages(),
    entry_points={
        "console_scripts": [
            "mpm-play=mpmplay.cli:cli"
        ]
    },
    classifiers=(
        "License :: OSI Approved :: GNU General Public License v3 (GPLv3)",
        "Natural Language :: English",
        "Programming Language :: Python",
        "Programming Language :: Python :: 3 :: Only"
    ))