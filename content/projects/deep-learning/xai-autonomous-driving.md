---
title: "Explainable AI for Autonomous Driving"
date: 2023-06-01
tag: "deep learning"
url: "/papers/xai-autonomous-driving.pdf"
featured: true
tech:
  - "Python"
  - "PyTorch"
  - "Computer Vision"
  - "Reinforcement Learning"
summary: |-
  An eight-author study of what it takes for a self-driving agent to explain
  itself: benchmarking saliency, factorization, and captioning methods on crash
  footage, measuring what survives a shift to the marine domain, and proposing a
  contingency-aware framework for the driving pipeline.
references:
  - https://notes.amittai.studio/deep-learning
  - https://notes.amittai.studio/artificial-intelligence
---

An autonomous vehicle is a decision procedure whose interior is opaque even to
its authors. The networks that drive it are accurate and unaccountable at once,
and the two properties are not in tension by accident: capacity purchased
through depth is capacity withdrawn from inspection. Acceptance of such agents
turns on a narrower question than accuracy. When a car brakes, swerves, or
declines to act, an operator, a passenger, and an accident investigator each
require an answer to _why_, and the answer must be legible to them rather than
to the optimizer. This team study surveys the explanation methods available to
self-driving agents, subjects them to experiment on crash footage, and proposes
where in the pipeline explanation ought to live.

$$
% caption: The black box problem. Sensor data enters an opaque model and
% caption: predictions leave it; an explanation interface is the sole bridge
% caption: from the model to debugging, operator trust, and insight.
\begin{tikzpicture}[
    font=\small,
    box/.style={draw=black!55, align=center, inner sep=6pt, minimum height=0.95cm, minimum width=2.3cm},
    dark/.style={draw=black!70, very thick, double, align=center, inner sep=8pt, minimum height=1.1cm, minimum width=2.6cm},
    exp/.style={draw=acc, fill=acc!10, align=center, inner sep=6pt, minimum height=0.95cm, minimum width=2.6cm},
    flow/.style={->, >=stealth, draw=black!50, thick},
    eflow/.style={->, >=stealth, draw=acc, thick}
  ]
  \definecolor{acc}{HTML}{2348F2}
  \node[box] (data) at (0,0) {sensor data};
  \node[dark] (model) at (3.6,0) {black box\\model};
  \node[box] (pred) at (7.3,0) {predictions};
  \node[exp] (exp) at (3.6,2.1) {explanation};
  \node[box] (debug) at (-0.2,2.1) {debug models};
  \node[box] (trust) at (7.5,2.1) {build trust};
  \node[box] (insight) at (3.6,4.0) {scientif\/ic insight};

  \draw[flow] (data) -- (model);
  \draw[flow] (model) -- (pred);
  \draw[eflow] (model) -- (exp);
  \draw[eflow] (exp) -- (debug);
  \draw[eflow] (exp) -- (trust);
  \draw[eflow] (exp) -- (insight);
\end{tikzpicture}
$$

**The partition.** Explainability in the driving stack is not one problem. It
factors along the pipeline, and each factor admits a different species of
answer:

- **Perception** turns camera, LiDAR, RADAR, and GPS returns into a
  representation of the scene. Its explanations are attributions over input:
  gradient methods (class saliency maps, Grad-CAM, DeConvNet, guided
  backpropagation), activation methods (CAM, attention branch networks,
  layer-wise relevance propagation), and perturbational methods (LIME, SHAP)
  that interrogate the model by occlusion.
- **Localization** places the vehicle inside that representation. The lineage
  runs from landmark-based maximum a posteriori estimation through the extended
  Kalman filter — convergent but brittle under compounding association error —
  to the graph-based formulation, where raw measurements become edges encoding
  transition distributions between candidate poses. Explanation here is
  attribution over sensors rather than pixels.
- **Planning** selects trajectories against a predicted cost over progress,
  comfort, safety, and fuel. It is the least explained stage of the stack;
  search-based planners compose motion, behavior, and mission planning in
  parallel, and almost no interpretive tooling exists for the composite.
- **System management** governs what the vehicle records about itself.
  Authenticity is served by a blockchain event recorder: vehicles within
  dedicated short-range communication form a federation, a lead verifier
  writes accident data to the chain, and an adversary must compromise a
  majority of community or federation in real time. Integrity is served by a
  smart black box built on deterministic memory machines with local buffer
  optimization, compressing gigabit-per-second onboard streams by data value
  rather than recency, with a priority queue evicting the cheap.

**Attribution formalized.** For a class score $y^c$ and the activation maps
$A^k$ of a final convolutional layer, Grad-CAM weights each map by the
spatially pooled gradient

$$
\alpha_k^c
= \frac{1}{Z} \sum_i \sum_j \frac{\partial y^c}{\partial A_{ij}^k},
\qquad
L^c
= \operatorname{ReLU}\!\Big(\sum_k \alpha_k^c A^k\Big),
$$

and the rectified combination $L^c$ localizes the evidence for $c$ without
altering the architecture — the property CAM lacks, being confined to networks
without fully connected heads. For localization, the analogous instrument is
the Shapley value over the sensor set $F$,

$$
\phi_i
= \sum_{S \subseteq F \setminus \{i\}}
\frac{\lvert S\rvert!\,\big(\lvert F\rvert - \lvert S\rvert - 1\big)!}{\lvert F\rvert!}
\Big( v\big(S \cup \{i\}\big) - v(S) \Big),
$$

which prices the marginal contribution of LiDAR against GNSS against inertial
measurement for a given pose estimate, averaged over every coalition of the
remaining sensors.

$$
% caption: Grad-CAM as an interface. The forward pass produces activation
% caption: maps and a class score; gradients pooled per map weight a
% caption: rectified combination rendered over the frame as a heat map.
\begin{tikzpicture}[
    font=\small,
    box/.style={draw=black!55, align=center, inner sep=6pt, minimum height=0.95cm, minimum width=2.2cm},
    hot/.style={draw=acc, fill=acc!10, align=center, inner sep=6pt, minimum height=0.95cm, minimum width=2.2cm},
    flow/.style={->, >=stealth, draw=black!50, thick},
    grad/.style={->, >=stealth, draw=acc, thick, dashed},
    lbl/.style={font=\scriptsize\ttfamily, text=black!55}
  ]
  \definecolor{acc}{HTML}{2348F2}
  \node[box] (frame) at (0,0) {input frame};
  \node[box] (conv) at (3.1,0) {conv backbone};
  \node[box] (act) at (6.3,0) {activation maps};
  \node[box] (score) at (9.5,0) {class score};
  \node[hot] (weight) at (6.3,-2.1) {weighted sum};
  \node[hot] (heat) at (2.9,-2.1) {saliency overlay};

  \draw[flow] (frame) -- (conv);
  \draw[flow] (conv) -- (act);
  \draw[flow] (act) -- (score);
  \draw[grad] (score) |- (weight);
  \node[lbl] at (8.35,-1.7) {pooled gradients};
  \draw[flow] (act) -- (weight);
  \draw[flow] (weight) -- (heat);
\end{tikzpicture}
$$

**Benchmarking on crash footage.** The experimental substrate is the CarCrash
Dataset, restricted to clips whose ego vehicle is directly involved so that
every attribution is egocentric. Over a Faster R-CNN backbone, class activation
mapping localizes cleanly when a single object owns the frame and degrades
precisely where an investigator needs it: with several vehicles of one class
present, the heat assigns credit to a neighboring car whose pixels dominate the
class score while the detector's boxes track a smaller, nearer one — and when
the frame truncates the salient vehicle, boxes fail to appear at all. A
semantic segmentation backbone repairs the granularity, scoring each pixel
within its own predicted class, though its maps decentralize as the subject
closes on the egocentric view. Deep feature factorization proved the sturdiest
of the visual methods, clustering the frame into abstract objects with no
output labels supplied, and segmenting the consequential regions of the crash
footage unsupervised.

**Explaining a control output.** PilotNet maps pixels to a steering command,
which makes its explanations answer for an action rather than a label. Grad-CAM
over the steering head attributed a recorded accident to the ego vehicle's own
lane crossing; the same model, modified to accept live OpenCV input, met the
failure mode that matters operationally — sun glare degrading attribution and
perception alike, an argument for redundant explainers rather than any single
one. ADAPT, a captioning transformer trained on the Berkeley DeepDrive
eXplanation corpus, narrates and justifies each control decision in natural
language; on crash clips its narration is accurate and myopic at once,
describing the ego vehicle's motion faithfully while missing the holistic
context of the collision.

$$
% caption: The domain shift result. Road saliency anchors on the lane
% caption: boundary; the marine domain supplies no boundary, and the
% caption: attribution has nothing to rest on.
\begin{tikzpicture}[
    font=\small,
    pane/.style={draw=black!55, minimum width=4.6cm, minimum height=3.0cm},
    lane/.style={draw=black!60, thick},
    wave/.style={draw=black!45, thick},
    blob/.style={draw=acc, fill=acc!14, thick},
    lbl/.style={font=\scriptsize, text=black!55, align=center}
  ]
  \definecolor{acc}{HTML}{2348F2}
  \node[pane] (road) at (0,0) {};
  \draw[lane] (-1.9,-1.3) -- (-0.4,1.3);
  \draw[lane] (1.9,-1.3) -- (0.5,1.3);
  \draw[blob, rotate around={60:(-1.05,-0.15)}] (-1.05,-0.15) ellipse [x radius=0.75cm, y radius=0.28cm];
  \node[lbl] at (0,-1.9) {road: attribution anchors\\on the lane boundary};

  \node[pane] (sea) at (6.4,0) {};
  \draw[wave] (4.3,0.55) .. controls (4.9,0.75) and (5.5,0.35) .. (6.1,0.55)
    .. controls (6.7,0.75) and (7.3,0.35) .. (7.9,0.55);
  \draw[wave] (4.3,-0.25) .. controls (4.9,-0.05) and (5.5,-0.45) .. (6.1,-0.25)
    .. controls (6.7,-0.05) and (7.3,-0.45) .. (7.9,-0.25);
  \draw[wave] (4.3,-1.0) .. controls (4.9,-0.8) and (5.5,-1.2) .. (6.1,-1.0)
    .. controls (6.7,-0.8) and (7.3,-1.2) .. (7.9,-1.0);
  \draw[blob] (5.3,0.9) ellipse [x radius=0.4cm, y radius=0.2cm];
  \draw[blob] (7.1,0.1) ellipse [x radius=0.35cm, y radius=0.18cm];
  \draw[blob] (5.9,-0.7) ellipse [x radius=0.3cm, y radius=0.18cm];
  \node[lbl] at (6.4,-1.9) {water: no boundary,\\attribution scatters};
\end{tikzpicture}
$$

**Where the explanation stops transferring.** The sharpest result is negative.
PilotNet, trained on road video, was run against maritime data collected by the
Dartmouth Robotics Lab — seventy gigabytes of `ROSBAG` recordings, two and a
half hours of time-synchronized RGB and inertial steering signal. The
transferred model failed outright; a model retrained on the marine data fared
little better, holding near $3.0$ mean squared error against under $1.0$ in the
car domain. Grad-CAM diagnosed the gap: road-domain saliency rests its mass on
the lane boundary, and open water supplies no such feature. The attribution did
not merely lose precision under domain shift; the causal anchor it had been
resting on was absent from the new domain entirely.

**Explaining a policy.** The planning stage answers to a different formalism.
An action-value satisfies the Bellman recursion over reward,

$$
Q(s, a) = R(s, a) + \gamma \sum_{s'} T(s, a, s')\, Q\big(s', \pi(s')\big),
$$

which states what the policy is worth while remaining silent on what the agent
will do. Substituting a named feature $F$ for the reward yields the generalized
value function,

$$
Q_F(s, a) = F(s, a) + \gamma \sum_{s'} T(s, a, s')\, Q_F\big(s', \pi(s')\big),
$$

the expected future course of a quantity a person chose: velocity, tilt angle,
distance to goal, landing-leg state. Learned alongside the policy of an
autonomous lunar lander, these functions trace each feature's trajectory as the
agent descends, and the trace reads as a statement of intent where the plain
$Q$ reads as a score.

$$
% caption: The proposed framework. Each stage emits its intrinsic and
% caption: post-hoc explanations as by-products; a contingency model prices
% caption: the reliability of each prediction and travels forward with it.
\begin{tikzpicture}[
    font=\small,
    stage/.style={draw=black!60, align=center, inner sep=6pt, minimum height=1.0cm, minimum width=2.5cm},
    exp/.style={draw=acc, fill=acc!10, align=center, inner sep=5pt, minimum height=0.85cm, minimum width=2.3cm},
    cont/.style={draw=grn, fill=grn!10, align=center, inner sep=5pt, minimum height=0.85cm, minimum width=2.3cm},
    flow/.style={->, >=stealth, draw=black!50, thick},
    eflow/.style={->, >=stealth, draw=acc, thick},
    cflow/.style={->, >=stealth, draw=grn, thick}
  ]
  \definecolor{acc}{HTML}{2348F2}
  \definecolor{grn}{HTML}{1E9E60}
  \node[stage] (perc) at (0,0) {perception};
  \node[stage] (plan) at (4.2,0) {planning};
  \node[stage] (pol) at (8.4,0) {policy};
  \node[stage] (dec) at (11.9,0) {decision};

  \node[exp] (pexp) at (0,2.0) {intrinsic\\explanation};
  \node[cont] (pcon) at (2.1,-2.0) {contingency\\model};
  \node[exp] (plexp) at (4.2,2.0) {post-hoc\\explanation};
  \node[cont] (plcon) at (6.3,-2.0) {contingency\\model};
  \node[exp] (polexp) at (8.4,2.0) {post-hoc\\explanation};

  \draw[flow] (perc) -- (plan);
  \draw[flow] (plan) -- (pol);
  \draw[flow] (pol) -- (dec);
  \draw[eflow] (perc) -- (pexp);
  \draw[eflow] (plan) -- (plexp);
  \draw[eflow] (pol) -- (polexp);
  \draw[cflow] (perc) -- (pcon);
  \draw[cflow] (pcon) -- (plan);
  \draw[cflow] (plan) -- (plcon);
  \draw[cflow] (plcon) -- (pol);
\end{tikzpicture}
$$

**The framework.** Intrinsic and post-hoc explanations already fall out of each
stage as by-products of prediction; the proposal is to stop discarding them.
Each stage acquires a contingency model estimating how far its own prediction
deserves trust, and that estimate travels forward with the prediction — so
planning receives what perception saw together with a price on the seeing.
Explanation becomes a first-class signal in the pipeline rather than an
artifact rendered for the postmortem.

**Scaling the instrumentation.** Interpretability work intervenes on
intermediate activations, and the prevailing tooling binds those interventions
to a particular authorship of the network: hook systems presuppose the
object-oriented module tree the model happened to be written as, while the
methods themselves grow stranger and the models larger. As proof of concept,
the study implements a system representing a model as a computational graph
over which a user matches sub-graphs to arbitrary functions — collecting and
manipulating activations with no reference to the model's internals or to the
idioms of its construction.

The conclusions are the experiments' own. No single method explains the
pipeline; the methods that read most clearly to a person are not the ones that
scale; and an attribution is only as durable as the feature it rests on, which
a change of domain may simply delete.

[perception]: https://notes.amittai.studio/deep-learning
