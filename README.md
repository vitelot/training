<div id="top"></div>




<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->


<!-- Vedi gli shield a fondo pagina -->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]



<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/github_username/repo_name">
    <img src="images/logo.png" alt="Logo" width="200" height="80">
  </a>

  <a href="https://github.com/github_username/repo_name">
    <img src="images/csh_logo.png" alt="Logo" width="200" height="80">
  </a>

<h3 align="center"> TRAINING: a delay tail handling simulation</h3>

  <p align="center">
    <br />
    <a href="https://github.com/github_username/repo_name"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/github_username/repo_name">View Demo</a>
    ·
    <a href="https://github.com/github_username/repo_name/issues">Report Bug</a>
    ·
    <a href="https://github.com/github_username/repo_name/issues">Request Feature</a>
  </p>
</div>

[![Main Programming Language][julia-shield]][julia-url]



branch main :

[![build-main](https://github.com/vitelot/training/actions/workflows/simulation_test.yml/badge.svg)](https://github.com/vitelot/training/actions/workflows/simulation_test.yml)

[![codecov](https://codecov.io/gh/vitelot/training/branch/main/graph/badge.svg?token=HHZI8L9MPJ)](https://codecov.io/gh/vitelot/training)

actual working branch:

[![build-test-branch](https://github.com/vitelot/training/actions/workflows/simulation_test.yml/badge.svg?branch=github_actions)](https://github.com/vitelot/training/actions/workflows/simulation_test.yml)

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#code-structure">Code Structure</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project


Simulating one day timetable for a Railway Network of trains

<p align="right">(<a href="#top">back to top</a>)</p>



### Built With

* [Julia](https://julialang.org/)


<p align="right">(<a href="#top">back to top</a>)</p>



<!-- GETTING STARTED -->
## Getting Started


 instructions on setting up your project locally.
To get a local copy up and running follow these simple example steps.

### Prerequisites

Software to be installed to run simulation.
* package_name
  ```sh
  install package package
  ```

### Installation
Procedure to locally set up the directory

1. Get a free API Key at [https://example.com](https://example.com)
2. Clone the repo
   ```sh
   git clone https://github.com/vitelot/training.git
   ```
3. Install packages
   ```sh
    install blabla
   ```


<p align="right">(<a href="#top">back to top</a>)</p>



<!-- USAGE EXAMPLES -->
## Usage


1. extract data/data.zip
2. in preprocessing/ , run
   ```sh
   ./run_preprocessing.sh
   ```
   this will move the unzipped data into the correct directory(data/simulation_data/), create /data/simulation_data/trains_beginning.ini for the starting of trains, create preprocessing/trainIni.in if not present (selection of trains to be delayed), and create the delay files in data/delays/

3. to run the simulation, in /run/ , run
   ```sh
   ./run.sh
   ```




useful examples of how the project can be used. Additional screenshots, code examples and demos work well in this space.

_For more examples, please refer to the [Article/Documentation](https://example.com)_

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- ROADMAP -->
## Roadmap

- [X] Add a parser for simulation
- [X] Add CI feature and codecov, getting better coverage
- [ ] Feature 3
    - [X] Done Nested Feature
    - [ ] Not Done Nested Feature

See the [open issues](https://github.com/github_username/repo_name/issues) for a full list of proposed features (and known issues).

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- CODE STRUCTURE -->

## Code Structure:

- [`/data/`](/data/) : zipped data to be preprocessed

- [`/images/`](/images/) : img needed for readme, for now

- [`/Preprocessing/`](/preprocessing/) : scripts to handle preprocessing; everything needed to create the input for the simulation
  - [preprocessing.jl](/preprocessing/preprocessing.jl) : script that takes the unzipped data, creates right repos in /data/ and moves and manipulates it

- [`/run/`](/run/) : containing script for running main.jl in /simulation/ (see following)

- [`/simulation/`](/simulation/) : libraries and main script of the simulation
  - [extern.jl](/simulation/extern.jl) : This file contains the definition of data structures,useful shortcuts,and the packages to be loaded. All the structs are commented, and we can find:
    - mutable struct `Block` : , which has block_id, number of tracks and trains actually in it
    - mutable struct `Network`: fixed part of the railway network, so operational points and blocks (infrastructure)
    - mutable struct `Delay` : struct for inserting the delay
    - struct `Transit`: struct that stands for Event on the timetable: train arrived in ops with a delay...
    - mutable struct `DynTrain`: dynamical part of Train: where it is and where it's going
    - mutable struct `Train`: struct with id, dyntrain, and its schedule
    - mutable struct `Fleet`: how trains interact with the infrastructure (sort of timetable but ordered by train_id)

  - [functions.jl](/simulation/functions.jl) : This file contains the definition of functions that are NOT needed for initializing our system on the infrastructure

    - function `dateToSeconds(d::String31)::Int` : Given a string in the format "yyyy-mm-dd HH:MM:SS" ; returns the number of seconds elapsed from the epoch
    - function `dateToSeconds(d::Int)::Int` : If the input is an Int do nothing; assuming that it is already the number of seconds elapsed from the epoch
    - function `runTest(RN::Network, FL::Fleet)` : If test mode is enabled, runs test without printing simulation results on std out
    - function `myRand(min::Float64, max::Float64)::Float64` : ranged random number generator
    - function `netStatus(S::Set{String}, BK::Dict{String,Block}; hashing::Bool=false)` : function that calculates the status of the simulation as a string of blocks and their occupancies in terms of train id; has also a hashing function to try to speed up
    - function `sort!(v::Vector{Transit})`
    - function `issorted(v::Vector{Transit})`

  - [initialize.jl](/simulation/initialize.jl) : This file contains all the functions that have to initialize the system. For example, loading the network, the block characteristics, the timetables
    - function `loadInfrastructure()::Network` : takes the blocks.csv file and builds the network
    - function `loadFleet()::Fleet` : takes the timetable.csv file and loads the Fleet
    - function `loadDelays()::Tuple{Vector{DataFrame},Int}` : Takes all the delay files in the data/delays/ directory and loads it in a vector of dataframes; each df defines a different simulation to be done
    - function `resetDelays(FL::Fleet,delays_array::Vector{DataFrame},simulation_id::Int)` : takes the vector of df, resets to 0 the delays imposed to the previews simulation
    - function `imposeDelays(FL::Fleet,delays_array::Vector{DataFrame},simulation_id::Int)` : imposes the delays for the actual simulation
    - function `initEvent(FL::Fleet)::Dict{Int,Vector{Transit}}` : Creates the Event dict, having times as keys and events in that time as values

  - [main.jl](/simulation/main.jl)
  - [parameters.jl](/simulation/parameters.jl) : This file contains the functions to load the simulation options from /data/simulation_data/par.ini; If not existing, creates one as default
  - [simulation.jl](/simulation/simulation.jl) : core part of the simulation; it is called in main.jl; returns false if the simulation doesn't get stuck, true otherwise

- [`/visualization/`](/visualization/) : basic visualization of the delays in the simulation  

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request (the feature will be added in the Roadmap)

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- LICENSE -->
## License

Distributed under the GNU GPL 3 License. See `LICENSE` for more information.

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- CONTACT -->
## Contact

Simone Daniotti - daniotti@csh.ac.at

Project Link: [https://github.com/vitelot/training](https://github.com/vitelot/training)

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

* [](OBB for funding the project)
* [](CSH Wien for mentoring and working place)
* []()

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/vitelot/training.svg?style=for-the-badge&logo=moleculer
[contributors-url]: https://github.com/vitelot/training/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/vitelot/training.svg?style=for-the-badge
[forks-url]: https://github.com/vitelot/training/network/members
[stars-shield]: https://img.shields.io/github/stars/vitelot/training.svg?style=for-the-badge&logo=startrek
[stars-url]: https://github.com/vitelot/training/stargazers
[issues-shield]: https://img.shields.io/github/issues/vitelot/training.svg?style=for-the-badge
[issues-url]: https://github.com/vitelot/training/issues
[license-shield]: https://img.shields.io/github/license/vitelot/training.svg?style=for-the-badge&logo=atari
[license-url]: https://github.com/vitelot/training/blob/dev/LICENSE
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-blue.svg?style=for-the-badge&logo=linkedin
[linkedin-url]: https://www.linkedin.com/in/vservedio/

[julia-shield]: https://img.shields.io/badge/Julia_vers-1.7.1-green?style=plastic&logo=julia
[julia-url]: https://julialang.org/downloads/

[product-screenshot]: images/screenshot.png
