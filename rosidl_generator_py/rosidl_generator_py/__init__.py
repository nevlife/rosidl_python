# Copyright 2014-2015 Open Source Robotics Foundation, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from .import_type_support_impl import import_type_support

__all__ = ['import_type_support']


def __getattr__(name):
    # Every generated message module imports this package for import_type_support; the
    # generator pulls in the IDL parser and the templating engine, so load it on first use.
    if name == 'generate_py':
        from .generate_py_impl import generate_py
        return generate_py
    raise AttributeError(f'module {__name__!r} has no attribute {name!r}')
