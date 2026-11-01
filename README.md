# Pull-up Video Analysis in MATLAB

A MATLAB App Designer application that analyzes recorded pull-up videos, counts candidate repetitions, and presents a workout report. Developed collaboratively as an academic image-processing project, it uses classical computer vision and rule-based analysis rather than a trained model.

## Features

- Load an MP4 or MOV video and view frames during analysis.
- Estimate pull-up bar height automatically, with manual correction.
- Track an upper foreground boundary within the center of the image.
- Count candidate repetitions and estimate their durations.
- Display per-frame measurements, a repetition table, and heuristic scores.
- Optionally estimate an external weight value from a manually selected image region.

## Requirements

- MATLAB with App Designer support.
- Image Processing Toolbox.
- Support for decoding the selected video through MATLAB's `VideoReader`.

The app has been opened and its startup checked in MATLAB R2025a. Compatibility with other releases has not been verified.

## Run the application

1. Download or clone this repository.
2. Open MATLAB and set its Current Folder to the repository directory.
3. Open `myApp.mlapp` in App Designer and click **Run**, or enter:

   ```matlab
   app = myApp;
   ```

4. Click **Load Video** and select `sample_videos/pull_up.MOV` or another supported video.
5. Check the red bar-height marker. If necessary, click **Set Bar Height**, then click the bar in the displayed image.
6. Optionally click **Set Weight** and select a rectangle around the weights in the separate selection window.
7. Click **Start Analysis**. A separate report window opens when processing finishes.

Keep `bg.jpeg` beside `myApp.mlapp`; it is used by the interface. The repository includes a sample video of approximately 24 MB.

## How the analysis works

1. **Reference frame:** The first video frame is stored as a fixed reference; it is not necessarily an empty background.
2. **Bar detection:** Canny edges and a Hough transform identify near-horizontal line segments in the upper part of the image. Grouping and gap rules select a candidate bar height.
3. **Foreground measurement:** Each frame is converted to grayscale and compared with the reference using an absolute difference. A fixed brightness threshold, a central region of interest, and small-component removal produce a binary mask.
4. **Feature extraction:** The mask area becomes a foreground-change score. The first row containing enough marked pixels provides an upper-boundary estimate.
5. **Repetition segmentation:** Crossing above a fixed mask-area threshold starts a candidate repetition; crossing below ends it. Segments longer than 0.5 seconds are retained.
6. **Reporting:** A heuristic score combines distance above the bar (80%) and segment duration (20%). The selected weight value is displayed but does not affect the score.

## Project files

| File | Purpose |
| --- | --- |
| `myApp.mlapp` | Interface, video processing loop, and repetition state management |
| `detectBarLogic.m` | Automatic bar-height estimation |
| `calcMotionLogic.m` | Reference-frame subtraction and per-frame measurements |
| `detectWeights.m` | Interactive, assumption-based weight estimation |
| `generateReport.m` | Plots, repetition scores, and summary table |
| `sample_videos/pull_up.MOV` | Example input video |
| `bg.jpeg` | Interface background image |
| `BgImage.jpeg` | Legacy image asset |

## Current validation and limitations

The existing analysis has been checked by a project author on one video and reported to work for that example. A broader accuracy evaluation has not yet been performed.

- The method assumes a stationary camera, relatively stable lighting, and a centered athlete. The first frame strongly affects subsequent measurements.
- Mask area measures change relative to the reference, not speed or physical exercise intensity. The upper boundary is not an anatomical chin detector.
- Fixed pixel thresholds make results dependent on resolution, framing, and camera distance.
- The stored height for each repetition is taken at maximum mask area, which may differ from the actual highest position.
- A single frame below the area threshold closes a segment. A segment still active at the end of the video is not recorded.
- Weight estimation assumes 20 kg per inferred plate after subtracting one detected segment; it is not a general weight-recognition system.
- Scores and feedback are application heuristics, not a validated assessment of exercise technique.

These limitations describe the current implementation and provide context for interpreting its output.
