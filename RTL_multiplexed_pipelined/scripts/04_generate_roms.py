import os
import math

def generate_rom(hex_file_path, out_file_path, module_name, data_width):
    with open(hex_file_path, 'r') as f:
        lines = [line.strip() for line in f if line.strip()]
    
    depth = len(lines)
    if depth == 0:
        addr_width = 1
    else:
        addr_width = math.ceil(math.log2(depth))
        if addr_width == 0:
            addr_width = 1

    with open(out_file_path, 'w') as f:
        f.write(f"`timescale 1ns / 1ps\n\n")
        f.write(f"module {module_name} (\n")
        f.write(f"    input  logic [{addr_width-1}:0] addr,\n")
        f.write(f"    output logic [{data_width-1}:0] data\n")
        f.write(f");\n\n")
        f.write(f"    always_comb begin\n")
        f.write(f"        case (addr)\n")
        for i, val in enumerate(lines):
            f.write(f"            {addr_width}'d{i}: data = {data_width}'h{val};\n")
        f.write(f"            default: data = {data_width}'d0;\n")
        f.write(f"        endcase\n")
        f.write(f"    end\n\n")
        f.write(f"endmodule\n")

def main():
    hex_dir = "hex_files"
    rtl_dir = "rtl"
    
    if not os.path.exists(rtl_dir):
        os.makedirs(rtl_dir)

    for filename in os.listdir(hex_dir):
        if not filename.endswith(".hex"):
            continue
            
        if "_W" in filename or "_b" in filename:
            name_no_ext = filename[:-4]
            module_name = f"rom_{name_no_ext}"
            out_file = os.path.join(rtl_dir, f"{module_name}.sv")
            
            data_width = 48 if "_W" in filename else 16
            
            generate_rom(os.path.join(hex_dir, filename), out_file, module_name, data_width)
            print(f"Generated {out_file} with width {data_width}")

if __name__ == "__main__":
    main()
