# CNN Inference Accelerator on an FPGA (Zynq-7020 / PYNQ-Z1) (Description t.b.f)

A hardware accelerated CNN inference engine in Verilog on the Xilinx Zynq-7020 SoC. The design performs single layer 2D convolution across 16 parallel MAC lanes over AXI-Stream, followed by ReLU activation layer and 2×2 max pooling, achieving 8.56× speedup over ARM Cortex-A9 software execution* with bit-exact output matching.

## Architecture:

!!!Create diagram and insert image here TODO!
Use draw.io? or something else like google drawing?!!!

- Note that each of the 16 output channels has its own conv → relu → max_pool pipeline 

- All 16 lanes share the same input pixel stream and operate in sync via a common clock enable (ce) 

- Outputs are packed into a single 256-bit wide bus and written to an output FIFO with AXI-Stream handshaking with skid logic

## Design Considerations:
- **16 Parallel convolution lanes**. Each lane contains a 

- **Fixed point A3.12 representation**. 16 bit **signed** representation: 1 sign bit, 3 integer bits, 12 fractional bits. |s|i|i|i|f|f|f|f|f|f|f|f. The MAC chain accumulates into 32 bit (A3.12 in -> A7.24 out). Then `relu_quantize.v` right shifts by 12 bits back into A3.12 with overflow/ saturation clamping to `16'sh7fff`.

- **Streaming Convolution Lanes via shift registers**. `conv.v`

- **Output FIFO with Skid Buffer**. The A 32-deep output FIFO with `SKID_THRESH = 3` provides backpressure via the `almost_full` signal. The `s_axis_tready` deasserts 3 entries before the FIFO is truly full, giving the upstream pipeline time to drain.

- **ReLU + quantisation**. Negative values clamped to zero via sign bit check. Positive values shifted right by `F_BITS` (12) and saturated if they overflow 16-bit range. Single pipeline stage.

- **Max pooling**

## Performance:

| Metric | Value |
|---|---|
| FPGA single-image latency* | 3.20 ms (incl. DMA + Python overhead) |
| ARM Cortex-A9 latency* | 27.35 ms (scipy.signal.convolve2d) |
| Speedup | 8.56× |
| Batch throughput (1000 * 28x28 images) | 983 images/sec |
| Verification/ Result Match (FPGA vs CPU) | Bit-exact across all 16 channels |

> **Measurement note:** The FPGA latency includes Python `time.perf_counter()` around serialised `dma.sendchannel.transfer()` → `wait()` → `recvchannel.transfer()` → `wait()`. The true hardware pipeline latency is significantly lower — on the order of ~10 clock cycles through the conv+relu+pool chain at 100 MHz. The batch measurement also serialises each DMA transfer, so the 983 FPS figure undercounts true hardware throughput. This is 100% to be improved on later in the **todo** section (likely with a hardware timer implentation).

**On true speedup measurement**: This initial comparison is just a purely python implentation. The reported 8.56× figure compares Python driven execution on both sides and is dominated by software overhead. 

The total workload on the arm chip is: 16 output channels × 26×26 output pixels × 9 multiply-accumulates per pixel = 97,344 MACs, plus ReLU (26×26×16 = 10,816) and max pooling (13×13×16 = 2704 comparisons).

By pure estimate and accounting for these factors:
- **CPU side** An optimised C implementation with NEON SIMD on the ARM Cortex-A9 at 650 MHz would likely complete the same workload much faster
- **DMA Overhead**
- **Hardware pipeline latency**

This suggests a realistic speedup in the range of 20–100× over well optimised C. A hardware cycle counter would be needed to confirm as a real measurement timer due to non deterministic tendencies from the petalinux OS.

## Resource Utilisation (Post-Implementation):

| Resource | Used | Available | Utilisation |
|---|---|---|---|
| LUT | ~10,108 | 53,200 | 19% |
| FF | ~4,488 | 106,400 | 8% |
| DSP48 | 144 | 220 | **65%** |
| BRAM | ~5.5 | 140 | 4% |
| LUTRAM | — | — | 17% |
| BUFG | — | — | 3% |

**Target:** xc7z020clg400-1 (PYNQ-Z1)  
**Clock:** 100 MHz (FCLK_CLK0 from PS)  
**Vivado:** 2025.1

The 144 DSP48 usage (65%) corresponds to 9 DSP48s × 16 channels = 144, confirming every MAC unit successfully mapped to a dedicated DSP48 slice (via the `*use_dsp = "yes"*` synth attributes) rather than using LUT based multiplication. 

## Timing (Post-Route):

| Parameter | Value |
|---|---|
| WNS (Worst Negative Slack) | **+0.237 ns** |
| WHS (Worst Hold Slack) | **+0.020 ns** |
| TNS | 0.000 ns |
| THS | 0.000 ns |
| Failing Endpoints | 0 |
| Total Endpoints | 50,127 |

All timing constraints met. The design closes at 100 MHz with 0.237 ns of setup margin, meaning the critical path delay is ~9.76 ns. Hold slack is tight at 20 ps but passing.

## Building and Running:

### Prerequisites
- Vivado 2022.x+ for synthesis/implementation
- PYNQ-Z1 board running PYNQ v2.7+
- Python 3 with `pynq`, `numpy`, `scipy`
- PyTorch (for retraining only)

### Training (optional — pre-trained weights included)
```bash
cd python
pip install torch torchvision numpy
python train_mnist.py            # → saves mnist_hw_model.pth
python weights_extraction.py     # → prints Verilog assign statements
```

### Synthesis
Open `conv_acc_v1.xpr` in Vivado, or create a project with all files under `rtl/` targeting xc7z020clg400-1. Run synthesis → implementation → generate bitstream.

### Deployment
1. Copy `accel_v2.bit` and `accel_v2.hwh` to the PYNQ board
2. Open `implementation/testing_notebook.ipynb` in Jupyter
3. Run all cells — verifies bit-exact match and reports latency/throughput

## Improvements for later:

## Acknowledgements
- https://thedatabus.in/convolver/ For inspiration on the conv stream engine
- https://www.udemy.com/course/fpga-project-cnn-accelerator-for-digit-recognition/. For inspiration to do MNIST on hardware implented CNN. Did not purchase the udemy course. Just watched the free preview video.
- Free Gemini AI via google searches. Frequent temporary google search Gemini AI prompts since all other AI platforms have **very tiny** free daily limits. Extremely useful as a buffed google search.