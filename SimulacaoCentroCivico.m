%CENTRO CIVICO, CURITIBA PR

% Definir local de localização central (células 1-3)
centerSite = txsite('Name','Curitiba Civic Center', ...
    'Latitude',-25.417500778124825, ...
    'Longitude',-49.26825505765927);

% Inicializa matrizes para distância e ângulo do local central até cada site de célula, onde cada site tem 3 células
numCellSites = 19;
siteDistances = zeros(1,numCellSites);
siteAngles = zeros(1,numCellSites);

% Definir distância e ângulo para anel interno de 6 locais (células 4-21)
isd = 200; % Distância entre locais
siteDistances(2:7) = isd;
siteAngles(2:7) = 30:60:360;

% Defina a distância e o ângulo para o anel intermediário de 6 locais (células 22-39)
siteDistances(8:13) = 2*isd*cosd(30);
siteAngles(8:13) = 0:60:300;

% Defina a distância e o ângulo para o anel externo de 6 locais (células 40-57)
siteDistances(14:19) = 2*isd;
siteAngles(14:19) = 30:60:360

% Definir parâmetros de célula
% Cada estação de célula possui três transmissores correspondentes a cada célula. 
% Inicializar matrizes para parâmetros de transmissores de células
numCells = numCellSites*3;
cellLats = zeros(1,numCells);
cellLons = zeros(1,numCells);
cellNames = strings(1,numCells);
cellAngles = zeros(1,numCells);

% Definir ângulos do setor celular
cellSectorAngles = [30 150 270];

% Para cada localização de célula, preencha os dados para cada transmissor de célula
cellInd = 1;
for siteInd = 1:numCellSites
   % Calcular a localização do site usando a distância e o ângulo do centro do site
    [cellLat,cellLon] = location(centerSite, siteDistances(siteInd), siteAngles(siteInd));
    
   % Atribuir valores para cada célula
    for cellSectorAngle = cellSectorAngles
        cellNames(cellInd) = "Cell " + cellInd;
        cellLats(cellInd) = cellLat;
        cellLons(cellInd) = cellLon;
        cellAngles(cellInd) = cellSectorAngle;
        cellInd = cellInd + 1;
    end
end

% Criar sites transmissores
fq = 3.5e9; % Frequência da portadora para Dense Urban-eMBB
antHeight = 25; % m
txPowerDBm = 43; % Potência total de transmissão em dBm
txPower = 10.^((txPowerDBm-30)/10); % Converter dBm em W

% Criar sites de transmissores de celular
txs = txsite('Name',cellNames, ...
    'Latitude',cellLats, ...
    'Longitude',cellLons, ...
    'AntennaAngle',cellAngles, ...
    'AntennaHeight',antHeight, ...
    'TransmitterFrequency',fq, ...
    'TransmitterPower',txPower);

% de lançamento do visualizador do site
viewer = siteviewer;

% Mostrar sites em um mapa
show(txs);
viewer.Basemap = 'topographic';

% Criar elemento de antena
% Definir parâmetros padrão
azvec = -180:180;
elvec = -90:90;
Am = 30; % Atenuação máxima (dB)
tilt = 0; % Ângulo de inclinaçao
az3dB = 65; % largura de banda de 3 dB em azimute
el3dB = 65; % largura de banda de 3 dB em elevação

% Definir padrão de antena
[az,el] = meshgrid(azvec,elvec);
azMagPattern = -12*(az/az3dB).^2;
elMagPattern = -12*((el-tilt)/el3dB).^2;
combinedMagPattern = azMagPattern + elMagPattern;
combinedMagPattern(combinedMagPattern<-Am) = -Am; % Saturar na atenuação máxima
phasepattern = zeros(size(combinedMagPattern));

% Criar elemento de antena
antennaElement = phased.CustomAntennaElement(...
    'AzimuthAngles',azvec, ...
    'ElevationAngles',elvec, ...
    'MagnitudePattern',combinedMagPattern, ...
    'PhasePattern',phasepattern);
   
% Exibir padrão de radiação
f = figure;
pattern(antennaElement,fq);

% Exibir mapa SINR para elemento de antena única
% Visualize SINR para o cenário de teste usando um único elemento de antena e o modelo de propagação em espaço livre. Para cada local no mapa dentro do alcance dos locais transmissores, a fonte do sinal é a célula com maior intensidade de sinal e todas as outras células são fontes de interferência. As áreas sem cor na rede indicam áreas onde o SINR está abaixo do limite padrão de -5 dB.
% Atribua o elemento de antena para cada transmissor de célula
for tx = txs
    tx.Antenna = antennaElement;
end

% Definido os parâmetros do receptor usando a Tabela 8-2 (b) do Relatório ITU-R M.[IMT-2020.EVAL]
bw = 200e6; % largura de banda de 20 MHz
rxNoiseFigure = 7; % dB
rxNoisePower = -174 + 10*log10(bw) + rxNoiseFigure;
rxGain = 0; % dBi
rxAntennaHeight = 1.5; % m

% Exibir mapa SINR
if isvalid(f)
    close(f)
end
sinr(txs,'freespace', ...
    'ReceiverGain',rxGain, ...
    'ReceiverAntennaHeight',rxAntennaHeight, ...
    'ReceiverNoisePower',rxNoisePower, ...    
    'MaxRange',isd, ...
    'Resolution',isd/20)

% Criar conjunto de antenas retangulares 8 por 8
% Defina um conjunto de antenas para aumentar o ganho direcional e aumentar os valores SINR de pico. Use a caixa de ferramentas do sistema Phased Array para criar uma matriz retangular uniforme de 8 por 8.
% Definir tamanho do array
nrow = 8;
ncol = 8;

% Definir espaçamento entre elementos
lambda = physconst('lightspeed')/fq;
drow = lambda/2;
dcol = lambda/2;

% Definir espaçamento entre elementos
dBdown = 30;
taperz = chebwin(nrow,dBdown);
tapery = chebwin(ncol,dBdown);
tap = taperz*tapery.'; % Multiplique as conicidades do vetor para obter valores de conicidade de 8 por 8

% Criar conjunto de antenas 8 por 8
cellAntenna = phased.URA('Size',[nrow ncol], ...
    'Element',antennaElement, ...
    'ElementSpacing',[drow dcol], ...
    'Taper',tap, ...
    'ArrayNormal','x');
    
% Exibir padrão de radiação
f = figure;
pattern(cellAntenna,fq);

% Exibir mapa SINR para matriz de antenas 8 por 8
% Visualize SINR para o cenário de teste usando um arranjo de antenas retangular uniforme e o modelo de propagação em espaço livre. Aplique uma inclinação mecânica para iluminar a área de aterramento pretendida ao redor de cada transmissor.
% Atribua o conjunto de antenas para cada transmissor de célula e aplique inclinação para baixo.
% Sem inclinação para baixo, o padrão é muito estreito para a vizinhança do transmissor.

downtilt = 15;
for tx = txs
    tx.Antenna = cellAntenna;
    tx.AntennaAngle = [tx.AntennaAngle; -downtilt];
end

% Display SINR mapa
if isvalid(f)
    close(f)
end
sinr(txs,'freespace', ...
    'ReceiverGain',rxGain, ...
    'ReceiverAntennaHeight',rxAntennaHeight, ...
    'ReceiverNoisePower',rxNoisePower, ...    
    'MaxRange',isd, ...
    'Resolution',isd/20)

% Exibir mapa SINR usando modelo de propagação aproximada
% Visualize SINR para o cenário de teste usando o modelo de propagação Close-In [3], que modela perda de caminho para cenários urbanos de microcélulas e macrocélulas 5G. Este modelo produz um mapa SINR que mostra efeitos de interferência reduzidos em comparação com o modelo de propagação no espaço livre.
sinr(txs,'close-in', ...
    'ReceiverGain',rxGain, ...
    'ReceiverAntennaHeight',rxAntennaHeight, ...
    'ReceiverNoisePower',rxNoisePower, ...    
    'MaxRange',isd, ...
    'Resolution',isd/20)

% Use antena de patch retangular como elemento de matriz
% A análise acima utilizou um elemento de antena que foi definido usando as equações especificadas no relatório ITU-R [1]. O elemento da antena precisa fornecer um ganho máximo de 9,5 dBi e uma relação frente-trás de aproximadamente 30 dB.
% Projeto de antena patch microfita retangular de meio comprimento de onda
patchElement = design(patchMicrostrip,fq);
patchElement.Width = patchElement.Length;
patchElement.Tilt = 90;
patchElement.TiltAxis = [0 1 0];

% Exibir padrão de radiação
f = figure;
pattern(patchElement,fq)

% Exibir mapa SINR usando o elemento de antena patch na matriz 8 por 8
% Mapa SINR para o modelo de propagação Close-In [3] usando a antena patch como elemento do array. Esta análise deve capturar o efeito dos desvios de uma especificação de antena baseada em equações, conforme o relatório ITU-R [1], incluindo:
        % Variações no ganho de pico
        % Variações na simetria do padrão com ângulos espaciais
        % de variações nas proporções frente-trás
        %Atribua a antena patch como elemento do array
cellAntenna.Element = patchElement;

% Display SINR mapa
if isvalid(f)
    close(f)
end
sinr(txs,'close-in',...
    'ReceiverGain',rxGain, ...
    'ReceiverAntennaHeight',rxAntennaHeight, ...
    'ReceiverNoisePower',rxNoisePower, ...    
    'MaxRange',isd, ...
    'Resolution',isd/20)
