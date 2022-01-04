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


<h3 align="center"> TRAINING: a delay tail handling simulation</h3>

  <p align="center">
    project_description
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
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project

[![Product Name Screen Shot][product-screenshot]](https://example.com)

Here's a blank template to get started: To avoid retyping too much info. Do a search and replace with your text editor for the following: `github_username`, `repo_name`, `twitter_handle`, `linkedin_username`, `email`, `email_client`, `project_title`, `project_description`

<p align="right">(<a href="#top">back to top</a>)</p>



### Built With

* [Julia](https://julialang.org/)


<p align="right">(<a href="#top">back to top</a>)</p>



<!-- GETTING STARTED -->
## Getting Started

This is an example of how you may give instructions on setting up your project locally.
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

- [X] Done Feature 1
- [ ] Feature 2
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
  - [`/simulation/`](/simulation/) TO BE DONE
  - nested
    - nested 2
    - nested 2


<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE.txt` for more information.

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- CONTACT -->
## Contact

Your Name - [@twitter_handle](https://twitter.com/twitter_handle) - email@email_client.com

Project Link: [https://github.com/vitelot/training](https://github.com/vitelot/training)

<p align="right">(<a href="#top">back to top</a>)</p>



<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

* []()
* []()
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

[julia-shield]: https://img.shields.io/badge/Julia_vers-1.6.4-green?style=plastic&logo=julia
[julia-url]: https://julialang.org/downloads/

[product-screenshot]: images/screenshot.png
