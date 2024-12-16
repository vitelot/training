# Railway Simulation Input Files

## stations.csv

Describes the characteristics of stations in the railway network.

### Columns
- `id`: Symbol of the station
- `ntracks`: Number of tracks available
- `nsidings`: Number of side tracks for special operations
- `length`: Length of tracks in the station (meters)
- `maxspeed`: Maximum speed (km/h) of trains that do not stop in the station
- `superblock`: Indicates shared track usage (0 = no special sharing)

### Example
```csv
id,ntracks,nsidings,length,maxspeed,superblock
S,4,2,300,60,0
A,4,4,400,60,0
POL,2,0,200,80,0
VEG,2,0,150,80,0
```

### Notes
- `superblock`: When set to a non-zero value, indicates a set of blocks and stations that can be used in both directions
- The same superblock cannot host more than one train simultaneously

## blocks.csv

Defines the characteristics of railway track blocks.

### Columns
- `block`: Symbol of the block
- `line`: ID of the railway line
- `length`: Block length (units)
- `direction`: Traffic direction (1 or 2)
- `tracks`: Number of tracks in the block
- `ismono`: Indicates if the track is used in both directions
- `superblock`: Shared track usage indicator
- `speed`: Maximum speed (can be multiple values separated by hyphens)

### Example
```csv
block,line,length,direction,tracks,ismono,superblock,speed
S-SN,10101,1200,2,1,0,0,80-140-250
SN-VEGS,10101,2340,2,1,0,0,80-140-250
VEGS-VEG,10101,1115,2,1,0,0,80-140-250
VEG-POLS,10101,1950,2,1,0,0,80-140-250
```

### Notes
- `direction`: Currently supports only values 1 or 2
- `ismono`: Boolean indicator of bidirectional track usage
- `speed`: Can specify multiple speed limits, likely for different train types or sections

## rotations.csv

Describes train dependencies and waiting conditions.

### Columns
- `train`: Symbol of the train
- `waitsfor`: Symbol of the train that must be completed first

### Example
```csv
train,waitsfor
SB_50002,SB_50000
```

### Notes
- Indicates that the second train must wait for the first one
- Typically due to shared rolling stock or personnel constraints

## timetable.csv

Provides detailed train movement schedule.

### Columns
- `train`: Train symbol
- `bst`: Operational point (Betriebstelle)
- `transittype`: Movement type
- `direction`: Line direction
- `line`: Line ID
- `distance`: Cumulative distance travelled
- `scheduledtime`: Seconds from midnight
- `daytime`: Human-readable time

### Transit Types
- `b`: Begin
- `p`: Entering station without stop
- `P`: Exiting station without stop
- `a`: Arrive
- `d`: Depart
- `e`: End

### Example
```csv
train,bst,transittype,direction,line,distance,scheduledtime,daytime
RJ_101,A,b,1,10101,0,21900,06:05:00
RJ_101,AS,p,1,10101,1500,21960,06:06:00
RJ_101,POLN,p,1,10101,3700,22020,06:07:00
```

## Imposed Delay Files (in /delays folder)

### Columns
- `trainid`: Train symbol
- `block`: Block or station symbol
- `delay`: Imposed delay in seconds

### Example
```csv
trainid,block,delay
SB_50000,POL,2600
RJ_101,POLS-VEG,120
```

### Notes
- Block can be a single station symbol or two symbols separated by a hyphen
- Delay specified in seconds from scheduled time