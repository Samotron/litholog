#!/usr/bin/env python3
"""
Setup script for litholog Python bindings.
"""

from setuptools import setup, find_packages
import os

# Read the README file
readme_path = os.path.join(os.path.dirname(__file__), "README.md")
if os.path.exists(readme_path):
    with open(readme_path, "r", encoding="utf-8") as fh:
        long_description = fh.read()
else:
    long_description = "Python bindings for litholog geological description parser"

setup(
    name="litholog",
    version="0.0.1",
    author="Litholog Project",
    author_email="contact@example.com",  # Update with real email
    description="Python bindings for litholog geological description parser",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/samotron/litholog",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Science/Research",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Topic :: Scientific/Engineering",
        "Topic :: Scientific/Engineering :: GIS",
        "Topic :: Software Development :: Libraries :: Python Modules",
    ],
    keywords="geology geological description parser BS5930 soil rock",
    python_requires=">=3.8",
    install_requires=[],
    extras_require={
        "dev": [
            "pytest>=6.0",
            "pytest-cov",
            "black",
            "flake8",
            "mypy",
            "twine",
            "wheel",
        ],
        "test": [
            "pytest>=6.0",
            "pytest-cov",
        ],
    },
    py_modules=["litholog"],
    package_data={
        "litholog": ["lib/*", "*.h"],
    },
    include_package_data=True,
    project_urls={
        "Bug Reports": "https://github.com/samotron/litholog/issues",
        "Source": "https://github.com/samotron/litholog",
        "Documentation": "https://github.com/samotron/litholog/tree/main/bindings/python",
    },
)