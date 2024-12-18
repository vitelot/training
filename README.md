# Railway Macroscopic Simulation

## Overview

This project implements a macroscopic simulation of railway system operations, providing a high-level approach to modeling train movements and network dynamics. Unlike point-by-point tracking, our simulation uses a queuing system model to analyze railway network performance.

## Key Simulation Characteristics

### Macroscopic Modeling Approach

The simulation operates on a block-based system, where:
- A block represents approximately 2 km of track section
- Only one train can occupy a block at a time
- Train movements are governed by block availability and timetable constraints

### Simulation Inputs

#### Required Input Files

1. **Blocks Configuration** (`blocks.csv`)
   - Defines the track sections and their properties

2. **Stations Configuration** (`stations.csv`)
   - Provides details about station locations and characteristics

3. **Timetable** (`timetable.csv`)
   - Specifies scheduled train movements and timing

#### Optional Input Files

- **Train Rotations** (`rotations.csv`)
  - Describes train dependencies between different train-services

- **Delay Scenarios** (files in `/delays` folder)
  - Allows simulation of various delay conditions and their network impact by specifying trains' delay at stations or on blocks

## Getting Started

### Prerequisites

- Julia (latest version recommended)
- Required dependencies (specified in `Project.toml`)

### Installation

```bash
# Clone the repository
git clone https://github.com/vitelot/training.git

# Enter the project directory
cd training

# Activate the project environment and install dependencies
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### Running the Simulation

To run the simulation, navigate to the `running/` directory and execute the `r` script:

```bash
# Navigate to the running directory
cd running

# Execute the simulation script
./r
```

This will start the railway system simulation using the configured input files.
If the parameter file `par.ini` does not exist it will create one.

## Documentation

Detailed documentation for each input file can be found in their respective folders. Please refer to the individual README files for specific format and content guidelines.

<!--
## Contributing

We welcome contributions! Please read our [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

[Specify your project's license, e.g., MIT License]

## Acknowledgments

- [List any references, inspirations, or acknowledgments]

-->
