#!/usr/bin/env python3
"""
Here we plot the task performance by parsing the logfiles

onset - time in seconds
duration - duration of event
sample - the current volume
trial_type - codes for what is in the logfile

TRIAL_TYPE contains DOT_FLIP, KEYPRESS, TRIGGER and FINISH

This will show intervals where there are more than two dot flips without a response.
"""
import sys
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt


def read_task(name):
    t = pd.read_csv(name, delimiter="\t")
    return t


def check_presses(t):
    missed_presses = []
    pressed = 0
    onset = 0
    t_ = t.loc[t["trial_type"].isin(["DOT_FLIP", "KEYPRESS"])]
    for index, row in t_.iterrows():
        if row["trial_type"] == "DOT_FLIP":
            if onset == 0:
                onset = row["onset"]
            else:
                missed_presses.append(onset)
                onset = 0
        else:
            onset = 0
    return missed_presses


def plot_task_performance(t, out=None):
    flips = t["onset"][t["trial_type"] == "DOT_FLIP"]
    keypress = t["onset"][t["trial_type"] == "KEYPRESS"]

    time_between_presses = np.diff(keypress)
    missed_presses = check_presses(t)

    fig, ax = plt.subplots(figsize=plt.figaspect(0.1))
    # ax.axis("off")

    for onset, time_between in zip(keypress[:-2], time_between_presses):
        if time_between > 5:
            ax.axvspan(onset, onset + time_between, color="red", alpha=0.6)

    ax.set(ylim=[-0.1, 2 * np.pi], yticks=[], xlim=[0, flips.values[-1]])
    for i in missed_presses:
        ax.axvline(i, ymax=0.3, linewidth=0.5, color="r")

    performance = t[t["trial_type"] == "FINISH"]["value"].values[0]
    ax.text(
        0.01,
        0.95,
        f"Hit Rate = {performance}",
        transform=ax.transAxes,
        weight=600,
        horizontalalignment="left",
        verticalalignment="top",
        size="medium",
    )

    # This essentially adds the task design.
    # plt.scatter(
    #     t[t["trial_type"] == "TRIGGER"]["onset"][1:],
    #     (t[t["trial_type"] == "TRIGGER"]["response_time"][1:] + np.pi) % (2 * np.pi),
    #     s=1,
    # )

    # for i in keypress:
    #     ax.axvline(i, color="red", linewidth=1)
    ax.set_title(
        "Red bars: missed keypresses. Red spans: gaps over 5 seconds without response."
    )

    if out is not None:
        plt.savefig(out, dpi=300)


if __name__ == "__main__":
    name = sys.argv[1]
    out = sys.argv[2]
    t = read_task(name)
    if t[t["trial_type"] == "FINISH"].any().values.sum() == 0:
        print(f"Apparently incomplete run for file {name}")
    else:
        plot_task_performance(t, out)
