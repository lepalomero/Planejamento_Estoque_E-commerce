if !isdefined(@__MODULE__, :estante)
    include(joinpath(@__DIR__, "layout_estoque.jl"))
end

function _pontos_consecutivos_unicos(pontos)
    resultado = Tuple{Float64,Float64}[]
    for ponto in pontos
        coordenada = (Float64(ponto[1]), Float64(ponto[2]))
        (isempty(resultado) || last(resultado) != coordenada) &&
            push!(resultado, coordenada)
    end
    return resultado
end

function _comprimento_caminho(pontos)
    return sum(
        abs(pontos[indice + 1][1] - pontos[indice][1]) +
        abs(pontos[indice + 1][2] - pontos[indice][2])
        for indice in 1:(length(pontos) - 1);
        init=0.0,
    )
end

function caminho_estantes(
    estante1,
    estante2,
    largura_armazem,
    comprimento_armazem,
)
    comprimento_armazem >= 2 ||
        throw(ArgumentError("comprimento_armazem deve ser pelo menos 2"))
    largura_armazem >= 0 ||
        throw(ArgumentError("largura_armazem nao pode ser negativa"))

    x1, y1 = Float64.(estante1.posicao)
    x2, y2 = Float64.(estante2.posicao)
    origem = (x1, y1)
    destino = (x2, y2)
    x1 == x2 && return _pontos_consecutivos_unicos((origem, destino))

    metade_comprimento = Float64(comprimento_armazem) / 2
    corredores = (0.0, -metade_comprimento, metade_comprimento)
    caminhos = [
        _pontos_consecutivos_unicos((
            origem,
            (corredor, y1),
            (corredor, y2),
            destino,
        ))
        for corredor in corredores
    ]
    comprimentos = _comprimento_caminho.(caminhos)
    return caminhos[argmin(comprimentos)]
end

function distancia_estantes(
    estante1,
    estante2,
    largura_armazem,
    comprimento_armazem,
)
    caminho = caminho_estantes(
        estante1,
        estante2,
        largura_armazem,
        comprimento_armazem,
    )
    return _comprimento_caminho(caminho)
end
