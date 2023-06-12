onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /testfixture/u_demosaic/clk
add wave -noupdate /testfixture/u_demosaic/reset
add wave -noupdate /testfixture/u_demosaic/in_en
add wave -noupdate /testfixture/u_demosaic/data_in
add wave -noupdate /testfixture/u_demosaic/first_data_ready
add wave -noupdate /testfixture/u_demosaic/image_block
add wave -noupdate /testfixture/u_demosaic/pixel_col
add wave -noupdate /testfixture/u_demosaic/pixel_row
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 267
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {238430 ps}
