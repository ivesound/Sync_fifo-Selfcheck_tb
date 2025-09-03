# Code your testbench here
import cocotb
import random

# FIFO DUT 
class FifoSync:
    def __init__(self, depth=16, width=8):
        self.depth = depth
        self.width = width
        self.mem = [0] * depth
        self.wptr = 0
        self.rptr = 0
        self.count = 0
        self.wfull = False
        self.rempty = True
        self.rdata = 0

    def cycle(self, wr_en, rd_en, wdata):
        """Simulate one clock posedge with NBA-like updates."""

        wr_ok = (wr_en and not self.wfull)
        rd_ok = (rd_en and not self.rempty)

        # Prepare next state
        next_wptr = self.wptr
        next_rptr = self.rptr
        next_count = self.count
        next_rdata = self.rdata

        if wr_ok:
            self.mem[self.wptr] = wdata
            next_wptr = (self.wptr + 1) % self.depth
            next_count += 1

        if rd_ok:
            next_rdata = self.mem[self.rptr]
            next_rptr = (self.rptr + 1) % self.depth
            next_count -= 1

        # Commit
        self.wptr = next_wptr
        self.rptr = next_rptr
        self.count = next_count
        self.rdata = next_rdata
        self.wfull = (self.count == self.depth)
        self.rempty = (self.count == 0)

#Testbench
def run_test(seed=1):
    random.seed(seed)
    fifo = FifoSync(depth=16, width=8)
    golden = []
    time = 0
    clk_period = 20  # like posedge every 10 time units in Verilog

    def tick(wr=0, rd=0, data=0):
        nonlocal time
        fifo.cycle(wr, rd, data)
        time += clk_period

    print("Starting FIFO test...")

    # 1. Write 10 values
    test_values = [random.randint(0, 255) for _ in range(10)]
    for val in test_values:
        fifo.cycle(1, 0, val)
        golden.append(val)
        time += clk_period

    # 2. Read 5 values
    for _ in range(5):
        fifo.cycle(0, 1, 0)
        exp = golden.pop(0)
        if fifo.rdata == exp:
            print(f"PASS: Read {exp} correctly at time {time}")
        else:
            print(f"ERROR: Expected {exp}, got {fifo.rdata} at time {time}")
        time += clk_period

    # 3. Fill until full
    while not fifo.wfull:
        val = random.randint(0, 255)
        fifo.cycle(1, 0, val)
        golden.append(val)
        time += clk_period
    print(f"FIFO is full at time {time} (golden count = {len(golden)})")

    # 4. Attempt extra writes
    for i in range(3):
        fifo.cycle(1, 0, random.randint(0, 255))
        time += clk_period
    print(f"Attempted 3 extra writes at time {time} (golden count should still be {len(golden)})")

    # 5. Drain FIFO
    while golden:
        fifo.cycle(0, 1, 0)
        exp = golden.pop(0)
        if fifo.rdata == exp:
            print(f"PASS: Read {exp} correctly at time {time}")
        else:
            print(f"ERROR: Expected {exp}, got {fifo.rdata} at time {time}")
        time += clk_period
    print(f"FIFO drained; golden count = {len(golden)}; DUT rempty={int(fifo.rempty)} at time {time}")

    # 6. Underflow attempts
    for i in range(3):
        prev_rdata = fifo.rdata
        fifo.cycle(0, 1, 0)
        if fifo.rdata == prev_rdata and fifo.rempty:
            print(f"PASS: Underflow attempt {i} did not change rdata/rempty at time {time}")
        else:
            print(f"ERROR: Underflow attempt {i} changed state at time {time}")
        time += clk_period
    print(f"Underflow attempts completed; golden count = {len(golden)} at time {time}")

    # 7. Sanity write/read
    sanity_val = random.randint(0, 255)
    fifo.cycle(1, 0, sanity_val)
    golden.append(sanity_val)
    time += clk_period

    fifo.cycle(0, 1, 0)
    exp = golden.pop(0)
    if fifo.rdata == exp:
        print(f"PASS: Sanity write/read OK ({exp}) at time {time}")
    else:
        print(f"ERROR: Sanity failed. Expected {exp}, got {fifo.rdata} at time {time}")
    time += clk_period

    print("All tests complete.")


if __name__ == "__main__":
    run_test()
