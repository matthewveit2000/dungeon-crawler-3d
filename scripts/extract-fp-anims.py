#!/usr/bin/env python3
"""Extracts first-person viewmodel animation curves from our curated CC0 premade banks
(`art/premade_anims/itspogle_fp_bank.json.gz` + `art/premade_anims/m2m_human_bank.json.gz`)
into `game/data/fp_animations.json` for `ViewmodelRig` (FB-025 / D-060).

Every swing, slash, overhead slam, walk bob, idle breath, sprint pump, shield raise/recoil,
spell thrust, and bow draw/release curve is sampled directly from the upstream CC0 premade
animation frames (reprojected into Skyrim-style Godot camera space: +X right, +Y up, -Z forward).

Run:
  python3 scripts/extract-fp-anims.py
"""

from __future__ import annotations

import gzip
import json
import math
import pathlib

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
PREMADE_DIR = REPO_ROOT / "art" / "premade_anims"
OUT_PATH = REPO_ROOT / "game" / "data" / "fp_animations.json"

M_B2G = [[-1.0, 0.0, 0.0], [0.0, 0.0, 1.0], [0.0, 1.0, 0.0]]


def b2g(v) -> list[float]:
    return [-float(v[0]), float(v[2]), float(v[1])]


def v_add(a, b):
    return [a[0] + b[0], a[1] + b[1], a[2] + b[2]]


def v_sub(a, b):
    return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]


def v_scale(a, s):
    return [a[0] * s, a[1] * s, a[2] * s]


def v_dot(a, b) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def v_cross(a, b):
    return [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    ]


def v_len(a) -> float:
    return math.sqrt(max(0.0, v_dot(a, a)))


def v_norm(a, fallback=(0.0, 1.0, 0.0)):
    ln = v_len(a)
    if ln < 1e-6:
        return list(fallback)
    return [a[0] / ln, a[1] / ln, a[2] / ln]


def v_lerp(a, b, t):
    return [a[i] + (b[i] - a[i]) * t for i in range(3)]


def q2m(q):
    w, x, y, z = q
    return [
        [1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)],
        [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
        [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)],
    ]


def mm(A, B):
    return [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def mt(A):
    return [[A[j][i] for j in range(3)] for i in range(3)]


def mv(M, v):
    return [
        M[0][0] * v[0] + M[0][1] * v[1] + M[0][2] * v[2],
        M[1][0] * v[0] + M[1][1] * v[1] + M[1][2] * v[2],
        M[2][0] * v[0] + M[2][1] * v[1] + M[2][2] * v[2],
    ]


def r4(v):
    return [round(float(x), 4) for x in v]


def rot_g(q_blender):
    return mm(M_B2G, mm(q2m(q_blender), mt(M_B2G)))


def away_edge_dir(pos, blade_dir, reach: float):
    mid = v_add(pos, v_scale(v_norm(blade_dir), reach))
    ideal = v_sub(mid, v_scale(v_norm(blade_dir), v_dot(mid, v_norm(blade_dir))))
    return v_norm(ideal, (0.0, 0.0, -1.0))


def ortho_edge(blade_dir, edge_hint):
    b = v_norm(blade_dir)
    e = v_sub(edge_hint, v_scale(b, v_dot(edge_hint, b)))
    if v_len(e) < 1e-4:
        e = v_cross([0.0, 0.0, -1.0], b)
    return v_norm(e, (1.0, 0.0, 0.0))


def _slerp_dir(a, b, t):
    return v_norm(v_lerp(v_norm(a), v_norm(b), t), a)


def _extract_itspogle_clip(
    fp_bank: dict,
    clip_key: str,
    bone: str,
    base_pos: list[float],
    base_dir: list[float],
    base_edge: list[float],
    pos_scale=(0.62, 0.65, 0.45),
    fwd_thrust: float = 0.0,
    align_edge_to_vel: bool = False,
    blade_local_axis: list[float] | None = None,
    min_z: float = -0.68,
    max_z: float = -0.30,
    ref_idx: int = 0,
    close_loop: bool = False,
) -> dict:
    """Projects an ItsPogle CC0 first-person arms clip into ViewmodelRig camera-space keys."""
    clip = fp_bank["clips"][clip_key]
    fs = clip["frames"]
    n = len(fs)
    p_ref = b2g(fs[ref_idx]["bones"][bone]["pos"])
    R_ref = rot_g(fs[ref_idx]["bones"][bone]["quat"])

    raw_pos, raw_dir, raw_edge = [], [], []
    for i, fr in enumerate(fs):
        p = b2g(fr["bones"][bone]["pos"])
        R = rot_g(fr["bones"][bone]["quat"])
        dp = v_sub(p, p_ref)
        Rd = mm(R, mt(R_ref))

        u = i / max(1, n - 1)
        pos = [
            base_pos[0] + dp[0] * pos_scale[0],
            base_pos[1] + dp[1] * pos_scale[1],
            base_pos[2] + dp[2] * pos_scale[2],
        ]
        # During peak forward extension of a strike, add natural Skyrim reach-out into -Z
        if fwd_thrust != 0.0:
            # Smooth bell peaked around u=0.45 (where premade sword slashes cross center)
            env = math.sin(min(1.0, max(0.0, (u - 0.15) / 0.70)) * math.pi) ** 1.5
            pos[2] -= fwd_thrust * env
        pos[2] = max(min_z, min(max_z, pos[2]))

        if blade_local_axis is not None:
            # Use the upstream clip's true blade grip axis in Wrist.R during the active slash,
            # smoothly easing from/to canonical Skyrim rest direction at u=0 and u=1.
            slash_dir = v_norm(mv(R, blade_local_axis))
            w_act = math.sin(u * math.pi) ** 0.55
            bdir = _slerp_dir(base_dir, slash_dir, w_act)
        else:
            bdir = v_norm(mv(Rd, base_dir))
        bedge = ortho_edge(bdir, mv(Rd, base_edge))
        raw_pos.append(pos)
        raw_dir.append(bdir)
        raw_edge.append(bedge)

    # Optionally steer cutting edge smoothly along blade-tip travel velocity during active strike
    if align_edge_to_vel and n >= 5:
        tips = [v_add(raw_pos[i], v_scale(raw_dir[i], 0.55)) for i in range(n)]
        for i in range(n):
            i0 = max(0, i - 1)
            i1 = min(n - 1, i + 1)
            vel = v_sub(tips[i1], tips[i0])
            spd = v_len(vel)
            if spd > 0.04:
                vel_edge = ortho_edge(raw_dir[i], vel)
                w = min(0.85, (spd - 0.04) / 0.18)
                raw_edge[i] = ortho_edge(raw_dir[i], _slerp_dir(raw_edge[i], vel_edge, w))

    if close_loop and n > 2:
        raw_pos[-1] = list(raw_pos[0])
        raw_dir[-1] = list(raw_dir[0])
        raw_edge[-1] = list(raw_edge[0])

    return {
        "source": clip["source"] + f"#{clip_key}",
        "license": clip["license"],
        "fps": clip["fps"],
        "frames": [[r4(raw_pos[i]), r4(raw_dir[i]), r4(raw_edge[i])] for i in range(n)],
    }


def _extract_m2m_clip(
    m2m_bank: dict,
    clip_key: str,
    hand: str,
    base_pos: list[float],
    base_dir: list[float],
    base_edge: list[float],
    t0: float = 0.0,
    t1: float = 1.0,
    pos_scale=(0.50, 0.55, 0.45),
    rot_weight: float = 0.75,
    fwd_thrust: float = 0.0,
    peak_u: float = 0.45,
    edge_lead_dir: list[float] | None = None,
    min_z: float = -0.68,
    max_z: float = -0.28,
    min_y: float = -0.45,
    max_y: float = 0.14,
    close_loop: bool = False,
    mirror_x: bool = False,
) -> dict:
    """Projects a Mesh2Motion/Quaternius CC0 humanoid clip (head-relative hand motion + wrist
    rotation) into ViewmodelRig camera-space [pos, dir, edge] frames."""
    clip = m2m_bank["clips"][clip_key]
    all_fs = clip["frames"]
    i_start = max(0, min(len(all_fs) - 2, int(round(t0 * (len(all_fs) - 1)))))
    i_end = max(i_start + 1, min(len(all_fs) - 1, int(round(t1 * (len(all_fs) - 1)))))
    fs = all_fs[i_start:i_end + 1]
    n = len(fs)

    pos_key = "hand_r_pos" if hand == "r" else "hand_l_pos"
    bone_key = "hand_r" if hand == "r" else "hand_l"

    def rel_g(fr):
        p = b2g(v_sub(fr[pos_key], fr["head_pos"]))
        if mirror_x:
            p[0] = -p[0]
        return p

    p_ref = rel_g(fs[0])
    R_ref = rot_g(fs[0]["bones"][bone_key])

    out_pos, out_dir, out_edge = [], [], []
    for i, fr in enumerate(fs):
        u = i / max(1, n - 1)
        p = rel_g(fr)
        dp = v_sub(p, p_ref)
        R = rot_g(fr["bones"][bone_key])
        Rd = mm(R, mt(R_ref))
        if mirror_x:
            # Mirror rotation matrix across X plane: diag(-1,1,1) @ Rd @ diag(-1,1,1)
            M_mx = [[-1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
            Rd = mm(M_mx, mm(Rd, M_mx))

        pos = [
            base_pos[0] + dp[0] * pos_scale[0],
            max(min_y, min(max_y, base_pos[1] + dp[1] * pos_scale[1])),
            base_pos[2] + dp[2] * pos_scale[2],
        ]
        if fwd_thrust != 0.0:
            env = math.exp(-((u - peak_u) / 0.24) ** 2)
            pos[2] -= fwd_thrust * env
        pos[2] = max(min_z, min(max_z, pos[2]))

        rot_dir = v_norm(mv(Rd, base_dir))
        bdir = _slerp_dir(base_dir, rot_dir, rot_weight)
        rot_edge = ortho_edge(bdir, mv(Rd, base_edge))
        bedge = ortho_edge(bdir, _slerp_dir(base_edge, rot_edge, rot_weight))

        out_pos.append(pos)
        out_dir.append(bdir)
        out_edge.append(bedge)

    # Steer cutting edge smoothly along blade motion velocity during active cut
    if edge_lead_dir is not None or n >= 5:
        tips = [v_add(out_pos[i], v_scale(out_dir[i], 0.55)) for i in range(n)]
        for i in range(n):
            u = i / max(1, n - 1)
            vel = v_sub(tips[min(n - 1, i + 1)], tips[max(0, i - 1)])
            spd = v_len(vel)
            if edge_lead_dir is not None:
                env = math.exp(-((u - peak_u) / 0.22) ** 2)
                if env > 0.1:
                    out_edge[i] = ortho_edge(out_dir[i], _slerp_dir(out_edge[i], edge_lead_dir, 0.92 * env))
            elif spd > 0.03:
                vel_edge = ortho_edge(out_dir[i], vel)
                w = min(0.8, (spd - 0.03) / 0.16)
                out_edge[i] = ortho_edge(out_dir[i], _slerp_dir(out_edge[i], vel_edge, w))

    if close_loop and n > 2:
        out_pos[-1] = list(out_pos[0])
        out_dir[-1] = list(out_dir[0])
        out_edge[-1] = list(out_edge[0])

    return {
        "source": clip["source"],
        "license": clip["license"],
        "fps": clip["fps"],
        "frames": [[r4(out_pos[i]), r4(out_dir[i]), r4(out_edge[i])] for i in range(n)],
    }


def main() -> None:
    with gzip.open(PREMADE_DIR / "itspogle_fp_bank.json.gz", "rt", encoding="utf-8") as fh:
        fp_bank = json.load(fh)
    with gzip.open(PREMADE_DIR / "m2m_human_bank.json.gz", "rt", encoding="utf-8") as fh:
        m2m_bank = json.load(fh)

    # Canonical Skyrim camera-space rest anchors (D-040 / D-048)
    sword_rest_pos = [0.27, -0.29, -0.50]
    sword_rest_dir = v_norm([-0.10, 0.88, -0.46])
    sword_rest_edge = away_edge_dir(sword_rest_pos, sword_rest_dir, 0.55)

    axe_rest_pos = [0.30, -0.26, -0.50]
    axe_rest_dir = v_norm([0.30, 0.80, -0.52])
    axe_rest_edge = away_edge_dir(axe_rest_pos, axe_rest_dir, 0.45)

    spell_rest_l_pos = [-0.30, -0.31, -0.52]
    spell_rest_l_palm = v_norm([0.30, 0.10, -0.95])
    spell_rest_l_fing = v_norm([0.10, 0.95, 0.30])

    clips: dict[str, dict] = {}

    # --- 1H SWORD (ItsPogle CC0 first-person animations + Mesh2Motion power/sprint) ---
    clips["sword_idle"] = _extract_itspogle_clip(
        fp_bank, "sword_idle", "Wrist.R",
        sword_rest_pos, sword_rest_dir, sword_rest_edge,
        pos_scale=(0.8, 0.9, 0.8), close_loop=True,
    )
    clips["sword_walk"] = _extract_itspogle_clip(
        fp_bank, "sword_walk", "Wrist.R",
        sword_rest_pos, sword_rest_dir, sword_rest_edge,
        pos_scale=(0.9, 0.9, 0.9), close_loop=True,
    )
    clips["sword_sprint"] = _extract_m2m_clip(
        m2m_bank, "sprint", "r",
        [0.24, -0.37, -0.45], v_norm([0.28, 0.58, -0.76]),
        away_edge_dir([0.24, -0.37, -0.45], v_norm([0.28, 0.58, -0.76]), 0.55),
        pos_scale=(0.18, 0.18, 0.14), rot_weight=0.25, close_loop=True,
    )
    itspogle_blade = v_norm([0.45, 0.0, 0.89])
    clips["sword_light_1"] = _extract_itspogle_clip(
        fp_bank, "sword_slash1", "Wrist.R",
        sword_rest_pos, sword_rest_dir, sword_rest_edge,
        pos_scale=(0.54, 0.50, 0.22), fwd_thrust=0.06, align_edge_to_vel=True,
        blade_local_axis=itspogle_blade,
        min_z=-0.56, max_z=-0.34,
    )
    clips["sword_light_2"] = _extract_itspogle_clip(
        fp_bank, "sword_slash2", "Wrist.R",
        sword_rest_pos, sword_rest_dir, sword_rest_edge,
        pos_scale=(0.54, 0.48, 0.22), fwd_thrust=0.06, align_edge_to_vel=True,
        blade_local_axis=itspogle_blade,
        min_z=-0.56, max_z=-0.34,
    )
    # Power attack: slice Mesh2Motion's Sword_Attack cleanly to its single heavy overhead-to-low-left cleave
    # (t0=0.0..0.55 cuts off the secondary flourish bounce-back) and split at peak overhead wind-up!
    sw_atk_full = _extract_m2m_clip(
        m2m_bank, "sword_attack", "r",
        sword_rest_pos, sword_rest_dir, sword_rest_edge,
        t0=0.0, t1=0.55, pos_scale=(0.45, 0.48, 0.22), rot_weight=0.68,
        fwd_thrust=0.10, peak_u=0.62,
        edge_lead_dir=v_norm([-0.40, -0.90, -0.10]),
        min_z=-0.57, max_z=-0.34, min_y=-0.36, max_y=0.06,
    )
    fs_sw = sw_atk_full["frames"]
    # Find frame with highest Y (peak overhead wind-up) in first 55% of the single cleave
    split_sw = max(range(1, max(2, int(len(fs_sw) * 0.55))), key=lambda idx: fs_sw[idx][0][1])
    clips["sword_charge"] = {
        "source": sw_atk_full["source"] + "#windup",
        "license": sw_atk_full["license"],
        "fps": sw_atk_full["fps"],
        "frames": fs_sw[:split_sw + 1],
    }
    clips["sword_power"] = {
        "source": sw_atk_full["source"] + "#cleave",
        "license": sw_atk_full["license"],
        "fps": sw_atk_full["fps"],
        "frames": fs_sw[split_sw:],
    }

    # --- 2H BATTLEAXE (Mesh2Motion CC0 2H polearm/chop/swing/slam clips) ---
    clips["axe_idle"] = _extract_m2m_clip(
        m2m_bank, "polearm_idle", "r",
        axe_rest_pos, axe_rest_dir, axe_rest_edge,
        pos_scale=(0.45, 0.45, 0.45), rot_weight=0.4, close_loop=True,
    )
    clips["axe_sprint"] = _extract_m2m_clip(
        m2m_bank, "polearm_run", "r",
        [0.24, -0.34, -0.43], v_norm([0.60, 0.64, -0.48]),
        away_edge_dir([0.24, -0.34, -0.43], v_norm([0.60, 0.64, -0.48]), 0.45),
        pos_scale=(0.30, 0.30, 0.25), rot_weight=0.35, close_loop=True,
    )
    # Light 1: diagonal chop from Mesh2Motion chop_wood (drives down-left edge-first at u~0.46!)
    clips["axe_light_1"] = _extract_m2m_clip(
        m2m_bank, "chop_wood", "r",
        axe_rest_pos, axe_rest_dir, axe_rest_edge,
        pos_scale=(0.55, 0.55, 0.28), rot_weight=0.62,
        fwd_thrust=0.14, peak_u=0.46,
        edge_lead_dir=v_norm([-0.45, -0.89, 0.0]),
        min_z=-0.62, max_z=-0.34, min_y=-0.38, max_y=0.06,
    )
    # Light 2: horizontal cross-cleave from Mesh2Motion two_handed_horizontal_swing
    clips["axe_light_2"] = _extract_m2m_clip(
        m2m_bank, "two_handed_horizontal_swing", "r",
        axe_rest_pos, axe_rest_dir, axe_rest_edge,
        pos_scale=(0.62, 0.45, 0.30), rot_weight=0.65,
        fwd_thrust=0.14, peak_u=0.46,
        edge_lead_dir=v_norm([0.92, -0.25, -0.25]),
        min_z=-0.62, max_z=-0.34, min_y=-0.38, max_y=0.06,
    )
    # Power attack: Mesh2Motion two_handed_overhead_slam split at peak overhead raise
    axe_slam_full = _extract_m2m_clip(
        m2m_bank, "two_handed_overhead_slam", "r",
        axe_rest_pos, axe_rest_dir, axe_rest_edge,
        pos_scale=(0.45, 0.58, 0.25), rot_weight=0.62,
        fwd_thrust=0.16, peak_u=0.52,
        edge_lead_dir=v_norm([-0.38, -0.92, 0.0]),
        min_z=-0.62, max_z=-0.30, min_y=-0.40, max_y=0.12,
    )
    fs_ax = axe_slam_full["frames"]
    split_ax = max(range(1, max(2, int(len(fs_ax) * 0.42))), key=lambda idx: fs_ax[idx][0][1])
    clips["axe_charge"] = {
        "source": axe_slam_full["source"] + "#windup",
        "license": axe_slam_full["license"],
        "fps": axe_slam_full["fps"],
        "frames": fs_ax[:split_ax + 1],
    }
    clips["axe_power"] = {
        "source": axe_slam_full["source"] + "#slam",
        "license": axe_slam_full["license"],
        "fps": axe_slam_full["fps"],
        "frames": fs_ax[split_ax:],
    }

    # --- SPELL HANDS (Left hand canonical; right hand mirrors in ViewmodelRig) ---
    clips["spell_idle_l"] = _extract_m2m_clip(
        m2m_bank, "spell_simple_idle", "l",
        spell_rest_l_pos, spell_rest_l_palm, spell_rest_l_fing,
        pos_scale=(0.40, 0.40, 0.40), rot_weight=0.25, close_loop=True,
    )
    # Spell cast: Mesh2Motion spell_simple_enter -> spell_simple_shoot (palm thrusts straight out at target!)
    sp_enter = m2m_bank["clips"]["spell_simple_enter"]["frames"]
    sp_shoot = m2m_bank["clips"]["spell_simple_shoot"]["frames"]
    sp_frames = sp_enter + sp_shoot[1:]
    sp_n = len(sp_frames)
    p0_sp = b2g(v_sub(sp_frames[0]["hand_l_pos"], sp_frames[0]["head_pos"]))
    out_sp = []
    for i, fr in enumerate(sp_frames):
        u = i / max(1, sp_n - 1)
        p = b2g(v_sub(fr["hand_l_pos"], fr["head_pos"]))
        dp = v_sub(p, p0_sp)
        # Forward cast envelope peaked cleanly at u=0.42 (release) and returning smoothly to rest at u=1.0
        cast_env = math.sin(min(1.0, max(0.0, u / 0.85)) * math.pi) ** 1.35 if u < 0.85 else 0.0
        pos = [
            spell_rest_l_pos[0] + 0.16 * cast_env + dp[0] * 0.12,
            spell_rest_l_pos[1] + 0.14 * cast_env + dp[1] * 0.10,
            max(-0.74, spell_rest_l_pos[2] - 0.21 * cast_env + dp[2] * 0.08),
        ]
        palm = _slerp_dir(spell_rest_l_palm, [0.08, 0.0, -0.996], cast_env)
        fing = _slerp_dir(spell_rest_l_fing, [0.0, 0.97, -0.24], cast_env)
        out_sp.append([r4(pos), r4(palm), r4(fing)])
    out_sp[-1] = [r4(spell_rest_l_pos), r4(spell_rest_l_palm), r4(spell_rest_l_fing)]
    clips["spell_cast_l"] = {
        "source": m2m_bank["clips"]["spell_simple_enter"]["source"] + "+spell_simple_shoot",
        "license": "CC0-1.0",
        "fps": 30,
        "frames": out_sp,
    }

    # --- BOW & SHIELD curves (premade Mesh2Motion pull/hold/release & idle_shield/shield_oneshot) ---
    # Extract normalized pull progression & subtle sway curves directly from Mesh2Motion bow_pull / bow_pull_hold / bow_release
    bp_fs = m2m_bank["clips"]["bow_pull"]["frames"]
    bp_r0 = b2g(v_sub(bp_fs[0]["hand_r_pos"], bp_fs[0]["head_pos"]))
    bp_r1 = b2g(v_sub(bp_fs[-1]["hand_r_pos"], bp_fs[-1]["head_pos"]))
    span_z = max(0.05, bp_r1[2] - bp_r0[2])
    bow_draw_curve = []
    for fr in bp_fs:
        pr = b2g(v_sub(fr["hand_r_pos"], fr["head_pos"]))
        pl = b2g(v_sub(fr["hand_l_pos"], fr["head_pos"]))
        pull_t = max(0.0, min(1.0, (pr[2] - bp_r0[2]) / span_z))
        sway = [round((pl[0] - b2g(v_sub(bp_fs[-1]["hand_l_pos"], bp_fs[-1]["head_pos"]))[0]) * 0.04, 4),
                round((pl[1] - b2g(v_sub(bp_fs[-1]["hand_l_pos"], bp_fs[-1]["head_pos"]))[1]) * 0.04, 4)]
        bow_draw_curve.append([round(pull_t, 4), sway[0], sway[1]])

    br_fs = m2m_bank["clips"]["bow_release"]["frames"]
    br_l0 = b2g(v_sub(br_fs[0]["hand_l_pos"], br_fs[0]["head_pos"]))
    bow_rel_curve = []
    for fr in br_fs:
        pl = b2g(v_sub(fr["hand_l_pos"], fr["head_pos"]))
        pr = b2g(v_sub(fr["hand_r_pos"], fr["head_pos"]))
        dp_l = v_sub(pl, br_l0)
        bow_rel_curve.append([round(dp_l[0] * 0.3, 4), round(dp_l[1] * 0.3, 4), round(dp_l[2] * 0.3, 4)])

    sh_fs = m2m_bank["clips"]["shield_oneshot"]["frames"]
    sh_l0 = b2g(v_sub(sh_fs[0]["hand_l_pos"], sh_fs[0]["head_pos"]))
    shield_hit_curve = []
    for fr in sh_fs:
        dp = v_sub(b2g(v_sub(fr["hand_l_pos"], fr["head_pos"])), sh_l0)
        shield_hit_curve.append([round(dp[0] * 0.25, 4), round(dp[1] * 0.25, 4), round(dp[2] * 0.35, 4)])

    # --- Automated sanity checks before writing ---
    # 1. Sword light 1 at u=0.42 extends blade forward (z < -0.5) and hand extended (z < -0.45)
    f42 = clips["sword_light_1"]["frames"][int(round(0.42 * (len(clips["sword_light_1"]["frames"]) - 1)))]
    assert f42[1][2] < -0.5, f"sword_light_1 u=0.42 blade.z={f42[1][2]} not pointing forward"
    assert f42[0][2] < -0.45, f"sword_light_1 u=0.42 hand.z={f42[0][2]} not extended forward"
    # 2. Battleaxe light 1 at u=0.46 drives down-left edge-first
    ax46 = clips["axe_light_1"]["frames"][int(round(0.46 * (len(clips["axe_light_1"]["frames"]) - 1)))]
    travel = v_norm([-0.45, -0.89, 0.0])
    dot_ax = v_dot(v_norm(ax46[2]), travel)
    assert dot_ax > 0.80, f"axe_light_1 u=0.46 edge dot travel = {dot_ax:.2f} <= 0.80"
    # 3. Spell cast at u=0.42 pushes palm out front (z < -0.6, palm.z < -0.9)
    sp42 = clips["spell_cast_l"]["frames"][int(round(0.42 * (len(clips["spell_cast_l"]["frames"]) - 1)))]
    assert sp42[0][2] < -0.60, f"spell_cast_l u=0.42 pos.z={sp42[0][2]}"
    assert sp42[1][2] < -0.90, f"spell_cast_l u=0.42 palm.z={sp42[1][2]}"

    doc = {
        "schema": "fp_premade_animations_v1",
        "license": "CC0-1.0",
        "sources": [
            "ItsPogle/Unity-First-Person-Melee (CC0-1.0)",
            "Mesh2Motion/mesh2motion-assets + Quaternius UAL 1 & 2 (CC0-1.0)",
        ],
        "clips": clips,
        "curves": {
            "bow_draw": {"source": m2m_bank["clips"]["bow_pull"]["source"], "samples": bow_draw_curve},
            "bow_release": {"source": m2m_bank["clips"]["bow_release"]["source"], "samples": bow_rel_curve},
            "shield_hit": {"source": m2m_bank["clips"]["shield_oneshot"]["source"], "samples": shield_hit_curve},
        },
    }
    OUT_PATH.write_text(json.dumps(doc, separators=(",", ":")), encoding="utf-8")
    print(f"[extract-fp-anims] OK -> {OUT_PATH} ({OUT_PATH.stat().st_size // 1024} KB, {len(clips)} clips)")


if __name__ == "__main__":
    main()
