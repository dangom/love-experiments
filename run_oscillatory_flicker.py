#!/usr/bin/env python3
"""
Run a flickering checkerboard stimulus.
"""
import argparse
import subprocess
import os.path as op


def cli_parser():
    """
    Parse command line arguments to generate a call to my LOVE flickering checkerboard experiment.
    """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--blocked",
        help="Whether to have ON/OFF instead of sinusoidal modulation",
        action="store_false",
    )

    parser.add_argument(
        "--scalednoise",
        type=int,
        help="Whether to use scaled noise instead of a flickering checkerboard",
        default=0
    )


    parser.add_argument(
        "--exponent", type=int, help="Exponent of contrast modulation", default=1
    )
    parser.add_argument(
        "--luminance", type=float, help="Maximum luminance for stimulus", default=0.8
    )
    parser.add_argument(
        "--flicker", type=int, help="The flicker frequency in Hz", default=12
    )

    parser.add_argument(
        "--frequency",
        type=float,
        help="The stimulus oscillatory frequency",
        required=True,
    )

    parser.add_argument("--tr", type=float, help="The TR in seconds", required=True)
    parser.add_argument(
        "--n_volumes", type=int, help="The number of repetitions", required=True
    )

    parser.add_argument(
        "--offset",
        type=int,
        help="Offset in seconds to start experiment after 1st trigger",
        default=14,
        required=True
    )

    parser.add_argument(
        "--sub_id",
        type=str,
        help="The subject ID. USE SAME AS IN SCANNER REGISTRATION.",
        required=True
    )
    parser.add_argument(
        "--run_id",
        type=str,
        help="The run ID. Use same name as the task in the protocol.",
        required=True
    )
    return parser


def run():
    """
    Run love flicker with proper parameters.
    """
    parser = cli_parser()
    args = parser.parse_args()

    cmd = [
        "love",
        op.join(op.dirname(__file__), "oscillatory-flicker"),
        args.sub_id,
        args.run_id,
        str(args.frequency),
        str(args.exponent),
        str(args.luminance),
        str(int(args.blocked)),
        str(args.offset),
        str(args.tr * args.n_volumes + 3),
        str(args.flicker),
        str(args.scalednoise)
    ]

    subprocess.call(cmd)


if __name__ == "__main__":
    run()
