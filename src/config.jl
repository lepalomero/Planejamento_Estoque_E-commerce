struct ConfigEstoque
    ocupacao_min::Float64
    ocupacao_max::Float64
    capacidade_prateleira::Float64
    prateleiras_por_estante::Int
    n_estantes::Int
    abc_percentuais::NTuple{3,Float64}
    variedade_por_estante::Int
    quantidade_maxima_estantes_item::Int
    largura_armazem::Int
    comprimento_armazem::Int
    posicao_saida::Tuple{Int,Int}
    semente::Int
end

function ConfigEstoque(;
    ocupacao_min=0.53,
    ocupacao_max=0.90,
    capacidade_prateleira=Inf,
    prateleiras_por_estante=3,
    n_estantes=nothing,
    abc_percentuais=(70, 20, 10),
    variedade_por_estante=3,
    quantidade_maxima_estantes_item=1,
    largura_armazem=40,
    comprimento_armazem=80,
    posicao_saida=(0, 0),
    semente=7,
)
    largura_armazem > 0 || throw(ArgumentError("largura_armazem deve ser maior que zero"))
    comprimento_armazem >= 2 ||
        throw(ArgumentError("comprimento_armazem deve ser pelo menos 2"))
    n_estantes === nothing && (n_estantes = largura_armazem * comprimento_armazem)

    0 <= ocupacao_min <= ocupacao_max <= 1 ||
        throw(ArgumentError("As ocupacoes devem satisfazer 0 <= ocupacao_min <= ocupacao_max <= 1"))
    capacidade_prateleira > 0 ||
        throw(ArgumentError("capacidade_prateleira deve ser positiva"))
    all(>(0), (prateleiras_por_estante, n_estantes, variedade_por_estante, quantidade_maxima_estantes_item)) ||
        throw(ArgumentError("Prateleiras, estantes, variedade e limite por item devem ser positivos"))
    length(abc_percentuais) == 3 ||
        throw(ArgumentError("abc_percentuais deve conter tres percentuais"))
    all(>=(0), abc_percentuais) && sum(abc_percentuais) == 100 ||
        throw(ArgumentError("abc_percentuais deve somar 100"))
    length(posicao_saida) == 2 ||
        throw(ArgumentError("posicao_saida deve conter duas coordenadas"))

    return ConfigEstoque(
        Float64(ocupacao_min),
        Float64(ocupacao_max),
        Float64(capacidade_prateleira),
        Int(prateleiras_por_estante),
        Int(n_estantes),
        (Float64(abc_percentuais[1]), Float64(abc_percentuais[2]), Float64(abc_percentuais[3])),
        Int(variedade_por_estante),
        Int(quantidade_maxima_estantes_item),
        Int(largura_armazem),
        Int(comprimento_armazem),
        (Int(posicao_saida[1]), Int(posicao_saida[2])),
        Int(semente),
    )
end
