
struct prateleira
    capacidade_peso::Int
    capacidade_tamanho::Int
    altura::Int

end

struct estante
    numero_prateleira::Int
    prateleiras::Vector{prateleira}
    posicao::Int
 end

struct armazem
    comprimento_armazem::Int
    largura_armazem::Int
    lista_estantes::Vector{estante}
end

function gerar_estante(capacidade_peso, capacidade_tamanho, numero_prateleira, comprimento_armazem, largura_armazem)
    lista_estantes= empty((largura_armazem/2) * (comprimento_armazem-4))
    for i in 1:((comprimento_armazem/2)-1)
        for j in 0:(largura_armazem)
            if j%2==0
                estante.posicao= (i,j)
                estante.numero_prateleira= numero_prateleira
                lista_prateleiras= empty(numero_prateleira)
                for k in 1:numero_prateleira
                    prateleira.capacidade_peso= capacidade_peso
                    prateleira.capacidade_tamanho= capacidade_tamanho
                    prateleira.altura= k
                    lista_prateleiras[k]=prateleira
                end   
                estante.prateleiras=lista_prateleiras
                push!(lista_estantes,estante)
            end
        end        
    end  

    for w in lista_estantes
        p=copy(w)
        p.posicao= (-w.posicao[1],w.posicao[2])
        push!(lista_estantes,p)

    end      
end

