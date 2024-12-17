# **User Manual: Railway Network Simulation Program**

## **1. Overview**

This program simulates train operations on a railway network. It models train movements, block occupancy, scheduling, delays, and other dynamics to analyze railway performance.

### Key Features:
- Simulate train movements across railway networks.
- Analyze timetables, delays, and block utilizations.
- Support multi-scenario simulations with user-defined delay configurations.
- Generate outputs such as timetables and RailML-compatible files.

---

## **2. File Structure**

The program is modular and divided into multiple files:

| **File Name**       | **Description**                                         |
|---------------------|---------------------------------------------------------|
| `main.jl`           | Entry point for the simulation.                         |
| `initialize.jl`     | Loads and initializes the railway infrastructure.       |
| `blocks.jl`         | Contains definitions and operations for network blocks. |
| `functions.jl`      | Core logic and utility functions for simulation.        |
| `parameters.jl`     | Stores global parameters and options.                   |
| `parser.jl`         | Handles data parsing from input files.                  |
| `simulation.jl`     | Defines the main simulation engine.                     |
| `extern.jl`         | External dependencies and helper utilities.             |

---

## **3. Installation**

### **Prerequisites**
1. **Julia**: Install Julia from [julialang.org](https://julialang.org/).
2. **Required Packages**: Install the following Julia packages:
   ```julia
   using Pkg
   Pkg.add([
       "CSV", "DataFrames", "Dates"
   ])
   ```

### **Directory Setup**
Ensure your working directory has the following input files in a `/data` folder:
1. `blocks.csv` – Block information for the railway.
2. `stations.csv` – Station details.
3. `timetable.csv` – Train schedules.
4. `rotation.csv` – Rotational schedules (optional).
5. Delay files: Store imposed delays in `/data/delays`.

**Directory Layout Example**:
```
/project_folder
   /data
      blocks.csv
      stations.csv
      timetable.csv
      delays/
         delay1.csv
         delay2.csv
   main.jl
   initialize.jl
   ...
```

---

## **4. Configuration**

Edit the global parameters in **`parameters.jl`** to configure the program:

```julia
Opt = Dict(
    "block_file" => "data/blocks.csv",
    "station_file" => "data/stations.csv",
    "timetable_file" => "data/timetable.csv",
    "rotation_file" => "data/rotation.csv",
    "imposed_delay_repo_path" => "data/delays/",
    "multi_simulation" => true,
    "print_flow" => true,
    "save_timetable" => true
)
```

- **block_file**: Path to the railway block file.
- **station_file**: Path to station information file.
- **timetable_file**: Path to the train timetable file.
- **rotation_file**: Path to optional train rotation schedules.
- **imposed_delay_repo_path**: Folder path for delay files.
- **multi_simulation**: `true` to run multiple delay scenarios.
- **save_timetable**: Save output timetable to CSV or RailML format.

---

## **5. Running the Program**

1. Navigate to the project directory in the terminal.
2. Run the main script using Julia:
   ```bash
   julia main.jl
   ```

### **Program Workflow**
1. **Initialization**:
   - Loads network infrastructure (`blocks.csv`, `stations.csv`).
   - Reads the train timetable and fleet data.
2. **Simulation**:
   - Simulates train movements across blocks.
   - Handles delays, dependencies, and block conflicts.
   - Supports multi-scenario simulation if delays are provided.
3. **Output**:
   - Timetable saved as `timetable.csv` or RailML file in the output directory.

---

## **6. Input Files**

Refer to the README file in the running/simdata/ folder
## **7. Outputs**

- **Timetable CSV**: Saved in the current directory as `timetable.csv`.
- **RailML File**: Optional RailML-compatible timetable output.
- **Logs**: Printed logs display program flow, delays, and simulation progress.

---

## **8. Troubleshooting**

| **Issue**                               | **Solution**                                  |
|-----------------------------------------|-----------------------------------------------|
| Program can't find input files.         | Verify file paths in `parameters.jl`.         |
| Unexpected key errors.                  | Check input file columns for typos.           |

---
