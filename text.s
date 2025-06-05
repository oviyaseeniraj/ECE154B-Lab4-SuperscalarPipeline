.data 
.text 
.globl      MAIN  
MAIN: 	addi    s0, x0, 0          # countx = 0;    			# 00000413  0
	addi    s1, x0, 0          # county = 0;          			# 00000493	4
	addi    s2, x0, 0          # countz = 0;          			# 00000913	8
	addi    s3, x0, 0          # innercount = 0;       			# 00000993	c
	addi    t0, x0, 1          # x = 1					 		# 00100293	10
# beginning of the loop
	addi    t3, x0, 0          # outer = 0 						# 00000e13	14
	addi    t4, x0, 10         # end of the outer loop constant # 00a00e93	18
	addi    t6, x0, 4          # end of the inner loop constant # 00400f93	1c
OUTER:  beq     t3, t4, END        # using on purpose not   	# 03de0e63	20  NOT TAKEN
	andi    t1, t3, 1          # y=outer&1 	  				    # 001e7313	24
	and     t2, t0, t1         # z=x&y       z=x&y				# 0062f3b3	28
	beq     t0, x0, SKIPX       								# 00028463	2c  TAKEN
	addi    s0, s0, 1            # countx++;					# 00140413	30
SKIPX:  beq     t1, x0, SKIPY      								# 00030463	34  TAKEN
	addi    s1, s1, 1            # county++;					# 00148493	38
SKIPY:  beq     t2, x0, SKIPZ      								# 00038463	3c  TAKEN
	addi    s2, s2, 1            # countz++;					# 00190913	40
SKIPZ:  addi    t5, x0, 0            # beginning of inner loop 	# 00000f13	44  
INNER:  addi    t5, t5, 1            # inner++;   				# 001f0f13	48  
	addi    s3, s3, 1            # innercount++;  				# 00198993	4c
	bne     t5, t6, INNER   									# ffff1ce3	50  TAKEN
	addi    t3, t3, 1            # outer++;  					# 001e0e13	54
	jal     x0, OUTER											# fc9ff06f	58
END:    addi   x0, x0, 0										# 00000013	5c
