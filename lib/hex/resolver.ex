defmodule Hex.Resolver do
  defrecord Info, [:overriden]
  defrecord State, [:activated, :pending]
  defrecord Request, [:name, :req, :parent]
  defrecord Active, [:name, :version, :state, :parents, :possibles]

  alias Hex.Registry

  def resolve(requests, overriden, locked) do
    info = Info[overriden: Enum.into(overriden, HashSet.new)]

    { activated, pending } =
      Enum.reduce(locked, { HashDict.new, [] }, fn { name, version }, { dict, pending } ->
        active = Active[name: name, version: version, parents: [], possibles: []]
        dict = Dict.put(dict, name, active)
        pending = pending ++ get_deps(name, version, info)
        { dict, pending }
      end)

    req_requests =
      Enum.map(requests, fn { name, req } ->
        Request[name: name, req: req]
      end)

    pending = pending ++ req_requests
    do_resolve(activated, pending, info)
  end

  defp do_resolve(activated, [], _info) do
    Enum.map(activated, fn { name, Active[version: version] } ->
      { name, version }
    end) |> Enum.reverse
  end

  defp do_resolve(activated, [Request[] = request|pending], info) do
    active = activated[request.name]

    if active do
      possibles = Enum.filter(active.possibles, &vsn_match?(&1, request.req))
      active = active.possibles(possibles).parents(wrap(request.parent) ++ active.parents)

      if vsn_match?(active.version, request.req) do
        activated = Dict.put(activated, request.name, active)
        do_resolve(activated, pending, info)
      else
        backtrack(active, activated, info)
      end
    else
      case get_versions(request.name, request.req) do
        [] ->
          backtrack(activated[request.parent], activated, info)

        [version|possibles] ->
          new_pending = get_deps(request.name, version, info)

          state = State[activated: activated, pending: pending]
          new_active = Active[name: request.name, version: version, state: state,
                              possibles: possibles, parents: wrap(request.parent)]
          activated = Dict.put(activated, request.name, new_active)

          do_resolve(activated, pending ++ new_pending, info)
      end
    end
  end

  defp backtrack(nil, _activated, _info) do
    nil
  end

  defp backtrack(Active[state: state] = active, activated, info) do
    case active.possibles do
      [] ->
        Enum.find_value(active.parents, fn parent ->
          backtrack(activated[parent], activated, info)
        end)

      [version|possibles] ->
        active = active.possibles(possibles).version(version)
        pending = get_deps(active.name, version, info)

        activated = Dict.put(state.activated, active.name, active)
        do_resolve(activated, state.pending ++ pending, info)
    end
  end

  def get_versions(package, req) do
    Registry.get_versions(package)
    |> Enum.filter(&vsn_match?(&1, req))
    |> Enum.reverse
  end

  def get_deps(package, version, Info[overriden: overriden]) do
    { _, deps } = Registry.get_release(package, version)

    Enum.flat_map(deps, fn { name, req } ->
      if Set.member?(overriden, name) do
        []
      else
        [Request[name: name, req: req, parent: package]]
      end
    end)
  end

  defp vsn_match?(version, req) do
    nil?(req) or Version.match?(version, req)
  end

  defp wrap(nil), do: []
  defp wrap(arg), do: [arg]
end
