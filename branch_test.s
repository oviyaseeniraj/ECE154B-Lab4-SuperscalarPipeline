.data
.text
.globl main
main:
    addi s0, x0, 0          # count taken branches
    addi s1, x0, 0          # count not taken branches
    addi s2, x0, 0          # count mispredicted branches
    addi t0, x0, 0          # loop counter i
    addi t1, x0, 16         # loop limit

loop:
    andi t2, t0, 1
    beq  t2, x0, taken      # taken every other time
    addi s1, s1, 1          # count not taken
    jal x0, skip

taken:
    addi s0, s0, 1          # count taken

skip:
    addi t0, t0, 1
    bne t0, t1, loop

    addi x0, x0, 0          # end instruction
