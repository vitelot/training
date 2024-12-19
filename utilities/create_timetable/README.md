# Timetable Generator Script

## Description

The Julia script, `generate_timetable_from_trains.jl` generates a railway timetable using input train data and related infrastructure information. The script processes the input data and generates schedules based on train characteristics, routes, blocks, and station information.

The script leverages:
- `CSV.jl` and `DataFrames.jl` for data manipulation.
- `Dates.jl` for time calculations.
- Enumeration for classifying speed classes (`slow`, `normal`, `fast`, and `unknown`).

---

## Files

1. **`generate_timetable_from_trains.jl`**  
   A Julia script that:
   - Reads train information from the input files.
   - Parses train data such as stops, stop times, and speed classes.
   - Incorporates infrastructure data like blocks and stations.
   - Calculates and generates a timetable for trains.

2. **Input Files**:
   - **`trains.csv`**: Contains train schedules and details.
   - **`blocks.csv`**: Provides information about railway blocks (track sections).
   - **`stations.csv`**: Lists station information including tracks, sidings, and maximum speeds.

3. **Output Files**:
   - **`timetable.csv`**: The final generated timetable.

---

## CSV File Structures

### `trains.csv`

| Column Name      | Description                                                                 |
|------------------|-----------------------------------------------------------------------------|
| `type`          | Train type (e.g., `RJ` for Railjet, `SB` for S-Bahn).                       |
| `number`        | Train number (unique identifier).                                           |
| `stops`         | Sequence of stops represented as station codes (e.g., `S-A`).              |
| `stop_times`    | Stop durations for each station in seconds (e.g., `120-60-60-120`).        |
| `route`         | Complete route of the train (e.g., station sequences `S-SN-VEGS-VEG-...`).  |
| `locoID`        | Locomotive ID (e.g., `1116.001`).                                           |
| `speed_class`   | Train speed classification: `slow`, `normal`, or `fast`.                   |
| `starting_time` | Scheduled starting time of the train in HH:MM format (e.g., `06:00`).      |

---

### `blocks.csv`

| Column Name   | Description                                                                    |
|---------------|--------------------------------------------------------------------------------|
| `block`      | Block section identifier (e.g., `S-SN`, `VEGS-VEG`).                           |
| `line`       | Line number associated with the block.                                         |
| `length`     | Length of the block in meters.                                                 |
| `direction`  | Direction of travelling (e.g., `1` for southwards, `2` for northwards).          |
| `tracks`     | Number of tracks in the block.                                                 |
| `superblock` | Identifier for larger block with only one track that can be travelled in both directions.                                         |
| `speed`      | Speed limits for the block (e.g., `80-140-250` indicating limits per class).   |

---

### `stations.csv`

| Column Name   | Description                                                                    |
|---------------|--------------------------------------------------------------------------------|
| `id`         | Station identifier (e.g., `S`, `A`, `POL`).                                    |
| `ntracks`    | Number of tracks available at the station.                                     |
| `nsidings`   | Number of sidings available at the station.                                    |
| `length`     | Length of the station platform in meters.                                      |
| `maxspeed`   | Maximum permissible speed at the station in km/h.                              |
| `superblock` | Identifier for larger station block groupings.                                 |

---

## Usage Instructions

1. **Prerequisites**  
   Ensure you have Julia installed. Install required packages by running:
   ```julia
   using Pkg
   Pkg.add(["CSV", "DataFrames", "Dates"])
   ```

2. **Run the Script**  
   Place the input files (`trains.csv`, `blocks.csv`, `stations.csv`) in the working directory. Run the script:
   ```bash
   julia generate_timetable_from_trains.jl
   ```

3. **Output**  
   The script generates a `timetable.csv` file containing the processed timetable.

---

## Notes

- The script integrates information about train schedules (`trains.csv`), block details (`blocks.csv`), and station characteristics (`stations.csv`).
- Speed classes influence the average travelling time within blocks.
- Ensure the input files are formatted correctly and correspond to each other logically.

---

## Example

**Sample Input Files**:

1. **`trains.csv`**:
| type | number | stops       | stop_times   | route                              | locoID   | speed_class | starting_time |
|------|--------|-------------|--------------|-----------------------------------|----------|-------------|---------------|
| RJ   | 100    | S-A         | 180-300      | S-SN-VEGS-VEG-POLS-POL-POLN-AS-A  | 1116.001 | fast        | 06:00         |

2. **`blocks.csv`**:
| block   | line  | length | direction | tracks | superblock | speed       |
|---------|-------|--------|-----------|--------|------------|-------------|
| S-SN    | 10101 | 1200   | 2         | 1      |  0         | 80-140-250  |

3. **`stations.csv`**:
| id   | ntracks | nsidings | length | maxspeed | superblock |
|------|---------|----------|--------|----------|------------|
| S    | 4       | 2        | 300    | 60       | 0          |

---
