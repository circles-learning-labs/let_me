defmodule MyApp.PolicyCombinations.Checks do
  @moduledoc false

  # checks

  def min_handsomeness(%{handsomeness: h}, _, min_h), do: h >= min_h

  def min_likeability(%{likeability: l}, _, min_l), do: l >= min_l

  def own_resource(%{id: user_id}, %{user_id: user_id}), do: true
  def own_resource(_, _), do: false

  def role(%{role: role}, _, role), do: true
  def role(_, _, _), do: false

  def same_group(%{group_id: id}, %{group_id: id}), do: true
  def same_group(%{group_id: _}, %{group_id: _}), do: false

  def same_pet(%{pet_id: id}, %{pet_id: id}), do: true
  def same_pet(%{pet_id: _}, %{pet_id: _}), do: false

  def same_user(%{id: id}, %{id: id}), do: true
  def same_user(_, _), do: false

  # pre-hooks

  def preload_groups(%{} = subject, %{} = object) do
    {Map.put(subject, :group_id, 50), Map.put(object, :group_id, 50)}
  end

  def preload_pets(%{} = subject, %{} = object) do
    {Map.put(subject, :pet_id, 80), Map.put(object, :pet_id, 80)}
  end
end
