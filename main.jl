#bibliotecas utilizadas
using ZipFile, CSV, DataFrames

#Caminho para arquivo zip
caminho_zip = joinpath(@__DIR__, "data","archive.zip")

#Abrindo arquivo zip
zip = ZipFile.Reader(caminho_zip)
for arquivo in zip.files
    println(arquivo.name)
end
close(zip)

#ler zip, constroi um dicionário que cria uma chave com nome da tabela e um dataframe daquela tabela 
function ler_zip(caminho_zip)
    dicionario = Dict{String, DataFrame}()
    zip = ZipFile.Reader(caminho_zip)
    try 
       for arquivo in zip.files
            endswith(lowercase(arquivo.name), ".csv") || continue
            nome = replace(basename(arquivo.name), ".csv" => "")
            dicionario[nome] = CSV.read(read(arquivo), DataFrame; stringtype = String)
        end
    finally
        close(zip)
    end
    return dicionario
end

#analisando cada arquivo dentro do zip individualmente 

function informacao_colunas(dicionario)
    zip=ZipFile.Reader(caminho_zip)
    try 
        for coluna in dicionario
        end
    finally
    end
end


function ler_arquivos(caminho_zip, dicionario)