# Copyright 2016 Open Source Robotics Foundation, Inc.
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

"""Build read-only NumPy views whose bases retain the owning C message."""

import numpy

_EMPTY = numpy.empty(0, dtype=numpy.uint8)


class _MessageBuffer:
    def __init__(self, address, size, dtype, owner):
        self._owner = owner
        self.__array_interface__ = {
            'version': 3,
            'shape': (size,),
            'typestr': numpy.dtype(dtype).str,
            'data': (address, True),
        }


def _view(address, size, dtype, owner):
    # A non-null address makes NumPy accept empty sequences without allocating data.
    return numpy.asarray(_MessageBuffer(address or _EMPTY.ctypes.data, size, dtype, owner))
