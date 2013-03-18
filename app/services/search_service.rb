# Serviço para busca, métodos auxiliares que lidam com os parametros da requisição
# e com a chamada da busca pelos métodos individuais desacoplando ao máximo a lógica
# do controller e trazendo para esta classe
class SearchService
  attr_reader :params, :user, :filters

  def initialize(opts={})
    @params = opts[:params].clone
    @user = opts[:current_user]
    @filters = params[:f] ? params[:f].clone : {}
  end

  # Executa busca para as classes definidas pelo usuário
  def perform_klasses_results(opts)
    results = Hash.new

    # Para cada classe executa a busca correspondente
    klasses_for_search.each do |klass|
      if klass == SpaceSearch
        results[klass.to_s] = perform_results(klass, :preview => opts[:preview],
                                              :space_search => true)
      else
        results[klass.to_s] = perform_results(klass, :preview => opts[:preview])
      end
    end

    results
  end

  # Realiza a busca com os params já setados para uma classe
  def perform_results(klass, opts = { :preview => false,
                                      :space_search => false })

    per_page = search_per_page(opts[:preview])

    results = klass.perform(@params[:q], per_page, @params[:format],
                            @params[:page]).results

    if opts[:space_search]
      page = @params[:page].nil? ? 1 : @params[:page]
      options = { :page => page, :per_page => per_page }
      results = filter_and_paginate_my_spaces(results, @user, options)
    end

    results
  end

  # Faz a representação da busca em formato JSON
  # Recebe uma coleção de tipos de resultados
  def make_representable(collections)
    all = Array.new

    # Para cada tipo de resultado aplica o representer, transforma em JSON
    # e devolve apenas os values do Hash segundo o formato que o tokeninput recebe na view
    collections.each do |collection|
      unless collection.empty?
        representer = collection.extend(InstantSearch::CollectionRepresenter)
        itens = JSON.parse(representer.to_json)

        all << itens.values
      end
    end

    all.flatten!
  end

  # Se a action receber apenas um filtro é mostrada uma página individual
  def individual_page?
    @filters.size == 1
  end

  # Preview quando não é uma página individual
  def preview?
    !individual_page?
  end

  protected

  def has_filter?(entity)
    # Se os filtros não existirem está implícito que
    # todos os filtros estão ativados
    @filters.include?(entity) || @filters.empty?
  end

  # Define para quais classes serão feitas as buscas dependendo dos parametros
  def klasses_for_search
    klasses = Array.new

    # Verifica quais filtros estão ativos e
    # avalia a busca dos modelos correspondentes
    if @params[:action] == "environments"
      klasses << EnvironmentSearch if has_filter?("ambientes")
      klasses << CourseSearch if has_filter?("cursos")
      klasses << SpaceSearch if has_filter?("disciplinas")
    elsif @params[:action] == "profiles"
      klasses << UserSearch
    else
      klasses = [UserSearch, EnvironmentSearch, CourseSearch, SpaceSearch]
    end

    klasses
  end

  # Define a quantidade de resultados da busca que serão mostrados
  def search_per_page(preview)
    if @params[:format] == "json"
      if @params[:action] == "profiles"
        Redu::Application.config.instant_search_results_per_page
      else
        Redu::Application.config.instant_search_preview_results_per_page
      end
    elsif preview
      Redu::Application.config.search_preview_results_per_page
    else
      Redu::Application.config.search_results_per_page
    end
  end

  # Filtra somente os spaces que o usuário tem acesso
  # pagina de acordo com os parâmetros recebidos
  def filter_and_paginate_my_spaces(collection, user, params)
    # Filtra os espaços que o usuário tem acesso
    my_spaces = collection.select{ |space| user.has_access_to?(space) }

    Kaminari.paginate_array(my_spaces).page(params[:page]).
      per(params[:per_page])
  end
end
