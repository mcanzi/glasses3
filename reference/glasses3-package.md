# glasses3: Read and Plot 'Tobii Pro Glasses 3' Recordings

Reads recordings made with the 'Tobii Pro Glasses 3' wearable eye
tracker directly from the folder on the SD card, so 'Tobii Pro Lab' is
not needed. Gaze, pupil diameter, inertial measurement unit and sync
port data are read from the compressed JSON files into data frames,
along with the recording metadata. Samples can be aligned with sync port
pulses and cut into epochs around pulses, API events or any other
onsets. Further functions fill gaps in the time series, average samples
into time bins, add clock time and convert gaze directions to angles and
angular velocity. Pupil diameter and gaze position can be plotted.

## Details

Tobii is a trademark of Tobii AB. The package is not affiliated with or
endorsed by Tobii. It reads the files the eye tracker writes and
contains no Tobii software.

## See also

Useful links:

- <https://github.com/mcanzi/glasses3>

- <https://mcanzi.de/glasses3/>

- Report bugs at <https://github.com/mcanzi/glasses3/issues>

## Author

**Maintainer**: Massimiliano Canzi <massimiliano.canzi@uni-konstanz.de>
([ORCID](https://orcid.org/0000-0001-6124-0321)) \[copyright holder\]

Authors:

- Massimiliano Canzi <massimiliano.canzi@uni-konstanz.de>
  ([ORCID](https://orcid.org/0000-0001-6124-0321)) \[copyright holder\]
