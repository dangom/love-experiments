#!/usr/bin/env python3
"""
Run a blocked flickering checkerboard stimulus.
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
        "--on_blocksize",
        type=float,
        help="Duration of the ON block",
        required=True,
    )

    parser.add_argument(
        "--off_blocksize",
        type=float,
        help="Duration of the OFF block",
        required=True,
    )

    parser.add_argument(
        "--luminance", type=float, help="Maximum luminance for stimulus", default=0.8
    )
    parser.add_argument(
        "--flicker", type=int, help="The flicker frequency in Hz", default=12
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

    parser.add_argument(
        "--scalednoise",
        type=int,
        help="Whether to use scaled noise instead of a flickering checkerboard",
        default=0
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
        op.join(op.dirname(__file__), "blocked-flicker"),
        args.sub_id,
        args.run_id,
        str(args.on_blocksize),
        str(args.off_blocksize),
        str(args.luminance),
        str(args.offset),
        str(args.tr * args.n_volumes + 3),
        str(args.flicker),
        str(args.scalednoise)
    ]

    subprocess.call(cmd)


if __name__ == "__main__":
    run()
