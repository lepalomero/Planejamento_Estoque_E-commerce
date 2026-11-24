
struct prateleira
    capacidade_peso::Int
    capacidade_tamanho::Int
    altura::Int
end

struct estante
    numero_prateleira::Int
    prateleiras::Vector{prateleira}
    posicao::Tuple{Int, Int}
end

struct armazem
    comprimento_armazem::Int
    largura_armazem::Int
    lista_estantes::Vector{estante}
end

function gerar_estante(
    capacidade_peso::Int,
    capacidade_tamanho::Int,
    numero_prateleira::Int,
    comprimento_armazem::Int,
    largura_armazem::Int,
)
    capacidade_peso >= 0 || throw(ArgumentError("capacidade_peso nao pode ser negativa"))
    capacidade_tamanho >= 0 || throw(ArgumentError("capacidade_tamanho nao pode ser negativa"))
    numero_prateleira >= 0 || throw(ArgumentError("numero_prateleira nao pode ser negativo"))
    comprimento_armazem >= 2 || throw(ArgumentError("comprimento_armazem deve ser pelo menos 2"))
    largura_armazem >= 0 || throw(ArgumentError("largura_armazem nao pode ser negativa"))

    lista_estantes = estante[]
    ultima_posicao_x = div(comprimento_armazem, 2) - 1

    for x in 1:ultima_posicao_x
        for y in 0:2:largura_armazem
            prateleiras = prateleira[
                prateleira(capacidade_peso, capacidade_tamanho, altura)
                for altura in 1:numero_prateleira
            ]

            push!(lista_estantes, estante(numero_prateleira, prateleiras, (x, y)))

            # Mantem o layout simetrico nos dois lados do armazem.
            if x != 0
                push!(lista_estantes, estante(numero_prateleira, prateleiras, (-x, y)))
            end
        end
    end

    return lista_estantes
end

function gerar_armazem(
    capacidade_peso::Int,
    capacidade_tamanho::Int,
    numero_prateleira::Int,
    comprimento_armazem::Int,
    largura_armazem::Int,
)
    estantes = gerar_estante(
        capacidade_peso,
        capacidade_tamanho,
        numero_prateleira,
        comprimento_armazem,
        largura_armazem,
    )
    return armazem(comprimento_armazem, largura_armazem, estantes)
end

