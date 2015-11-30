% Converts a sinusoidal to an 18-bit Xilinx .COE file
% This can be used to initialize ROM

function SINEtoCOE(~)

% Create a GUI to grab the .COE output directory:
OutputDir = uigetdir('C:\Users\Rehan\OneDrive\Documents\ECE_540\FinalProject\hdl','Choose output directory for .COE file');

% Create the sinusoidal:
frequency = 1;
bins = 24;
n = linspace(0, 2*pi*frequency, bins);
wave = cos(n);

% Convert to fixed-point format (MSB = sign; 0:17 are fraction bits)
wave_fp = sfi(wave,18,17);

% Create a new .COE file & open it to start writing:
COE_FILE = strcat(OutputDir,'\wave.coe');
fid = fopen(COE_FILE,'w');

% Write header information:
fprintf(fid,';******************************************************************\n');
fprintf(fid,';****               Sinusoidal wave in .COE Format            *****\n');
fprintf(fid,';******************************************************************\n');
fprintf(fid,';\n');
fprintf(fid,'; This .COE file specifies sinusoidal values for a \n');
fprintf(fid,'; block memory of depth=%d, and width=12.\n', bins);
fprintf(fid,'; In this case, values are specified in signed fixed-point format.\n');
fprintf(fid,';\n');

% Write ROM initialization to file:
fprintf(fid,'memory_initialization_radix=2;\n');    % specify to Vivado that COE file is binary format
fprintf(fid,'memory_initialization_vector=\n');
fprintf(fid,';\n');

% Loop through every element writing binary value to file:

for j = 1:(bins-1)
    fprintf(fid,'%s,\n',bin(wave_fp(j)));
end

% Last entry has a semicolon instead of a comma:
fprintf(fid,'%s;\n',bin(wave_fp(bins)));

% Close file to prevent further editing:
fclose(fid);
