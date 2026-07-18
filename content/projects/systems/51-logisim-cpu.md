---
title: "Logisim Processor"
date: 2021-11-05
tag: "systems"
repo: "https://github.com/siavava/assembly/tree/main/cs51/practice/hw8"
featured: true
tech:
  - "Assembly"
  - "Computer Architecture"
summary: "A fully functional 16-bit CPU built in Logisim from bare gates — ALU, register file, micro-sequenced control, and memory-mapped IO, running real programs."
references:
  - https://notes.amittai.studio/computer-architecture/processor-design/the-fetch-decode-execute-cycle
  - https://notes.amittai.studio/computer-architecture/digital-logic/multiplexers-decoders-and-the-alu
  - https://notes.amittai.studio/computer-architecture/digital-logic/memory-elements-latches-flip-flops-and-clocking
---

A fully functional 16-bit [CPU](https://en.wikipedia.org/wiki/Central_processing_unit)
implemented in [Logisim](https://en.wikipedia.org/wiki/Logisim), built
up from bare gates: the
[ALU](https://en.wikipedia.org/wiki/Arithmetic_logic_unit), the register
file, the [control unit](https://en.wikipedia.org/wiki/Control_unit),
the [program counter](https://en.wikipedia.org/wiki/Program_counter),
RAM, a [micro-sequencer](https://en.wikipedia.org/wiki/Microsequencer)
driven by a [finite-state machine](https://en.wikipedia.org/wiki/Finite-state_machine),
and memory-mapped [IO](https://en.wikipedia.org/wiki/Input/output). It
runs real programs, hand-assembled into its own 16-bit instruction
encoding.

$$
% caption: The 16-bit machine assembles whole: the PC addresses RAM; the fetched word
% lands in the instruction register and splits into fields; the register
% file feeds the ALU, which sets the flags; results write back down the
% inner right margin, and the next PC loops down the outer one. The micro-
% sequenced FSM (left) reads the opcode and drives a control word to every
% unit, one micro-step per clock.
\begin{tikzpicture}[font=\footnotesize,>=stealth,
  u/.style={draw=acc, fill=acc!8, align=center, inner sep=3pt},
  wlab/.style={text=acc, font=\footnotesize\ttfamily}]
  \definecolor{acc}{HTML}{2348F2}
  % ===== central data spine, bottom (fetch) to top (write-back / next PC) =====
  \node[u, minimum width=20mm, minimum height=8mm]  (pc)  at (0,0)    {\texttt{PC}};
  \node[u, minimum width=30mm, minimum height=10mm] (ram) at (0,1.8)  {\texttt{RAM}\\(memory-mapped \texttt{IO})};
  \node[u, minimum width=30mm, minimum height=9mm]  (ir)  at (0,3.7)  {instruction register};
  \node[u, minimum width=30mm, minimum height=10mm] (rf)  at (0,5.6)  {register \texttt{file}};
  \node[u, minimum width=22mm, minimum height=10mm] (alu) at (0,7.7)  {\texttt{ALU}};
  \node[u, minimum width=22mm, minimum height=8mm]  (npc) at (0,9.7)  {next \texttt{PC}};
  % flags register beside the ALU
  \node[u, minimum width=12mm, minimum height=8mm] (cc) at (2.4,7.7) {f\/lags};
  \draw[->] (alu.east) -- (cc.west);
  \node[wlab] at (2.4,7.1) {Z N C V};
  % ----- central data hand-offs -----
  \draw[->] (pc.north) -- (ram.south)  node[wlab,midway,right]{addr};
  \draw[->] (ram.north) -- (ir.south)  node[wlab,midway,right]{word};
  \draw[->] (ir.north) -- (rf.south)   node[wlab,midway,right]{opcode, rA, rB, imm};
  \draw[->] (rf.north) -- (alu.south)  node[wlab,midway,right]{operands};
  \draw[->] (alu.north) -- (npc.south) node[wlab,midway,right]{result};
  % ----- write-back branches off the result bus, down the INNER margin -----
  \coordinate (jwb) at (0,8.85);
  \fill[acc] (jwb) circle (1.2pt);
  \draw[->, acc] (jwb) -- (3.6,8.85) -- (3.6,5.6) -- (rf.east);
  \node[wlab, rotate=-90, anchor=center] at (3.95,7.1) {write-back};
  % ----- next PC returns down the OUTER right margin -----
  \draw[->, acc] (npc.east) -- (4.8,9.7) -- (4.8,0) -- (pc.east);
  \node[wlab, rotate=-90, anchor=center] at (5.15,4.85) {next PC};
  % ===== control unit on the far left, spanning the height =====
  \node[u, minimum width=14mm, minimum height=100mm] (ctl) at (-5.4,4.85) {};
  \node[font=\footnotesize\ttfamily, rotate=90] at (-5.4,4.85) {FSM + micro-sequencer};
  \node[wlab, rotate=90, anchor=center] at (-6.45,4.85) {control word per micro-step};
  % control fan: one horizontal stub per unit, crossing nothing
  \draw[->, acc] (-4.7,0)   -- (pc.west);
  \draw[->, acc] (-4.7,1.8) -- (ram.west);
  \draw[->, acc] (-4.7,5.6) -- (rf.west);
  \draw[->, acc] (-4.7,7.7) -- (alu.west);
  \draw[->, acc] (-4.7,9.7) -- (npc.west);
  % the opcode comes back to the sequencer from the instruction register
  \draw[->, acc!70] (ir.west) -- (-4.7,3.7);
  \node[wlab, anchor=south] at (-3.1,3.75) {opcode};
\end{tikzpicture}
$$

**Everything reduces to gates.** The ALU's adder is a chain of full
adders; subtraction is addition of the two's complement; comparisons
fall out of the subtractor's sign and zero flags. Multiplexers built
from AND/OR trees steer every bus, and each register is a rank of
D flip-flops behind a write-enable. With $n$ select lines a multiplexer
chooses among $2^n$ inputs; the machine is built by applying that
identity at every scale.

**The control unit is a finite-state machine.** Each instruction takes
several clock cycles: fetch the word at the PC, decode its opcode,
execute its micro-operations. The micro-sequencer walks a ROM of control
words — one per state — asserting the right write-enables, bus selects,
and ALU function bits, then jumps back to fetch. Adding an instruction
means adding rows to that ROM, not rewiring the machine.
