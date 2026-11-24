
if !isdefined(@__MODULE__, :estante)
    include(joinpath(@__DIR__, "layout_estoque.jl"))
end

function distancia_estantes(
    estante1,
    estante2,
    largura_armazem,
    comprimento_armazem,
)
    x1, y1 = estante1.posicao
    x2, y2 = estante2.posicao

    comprimento_armazem >= 2 || throw(ArgumentError("comprimento_armazem deve ser pelo menos 2"))
    largura_armazem >= 0 || throw(ArgumentError("largura_armazem nao pode ser negativa"))

    distancia_y = abs(y1 - y2)

    # Caminho direto no grid.
    distancia_direta = abs(x1 - x2) + distancia_y

    metade_comprimento = comprimento_armazem / 2

    # Caminhos pelos corredores das extremidades esquerda e direita.
    distancia_esquerda =
        abs(x1 - (-metade_comprimento)) +
        distancia_y +
        abs(x2 - (-metade_comprimento))
    distancia_direita =
        abs(x1 - metade_comprimento) +
        distancia_y +
        abs(x2 - metade_comprimento)

    # Considera que a largura nao limita a posicao das estantes geradas.
    return min(distancia_direta, distancia_esquerda, distancia_direita)
end