defmodule Expel.PolicyTest do
  use ExUnit.Case, async: true
  doctest Expel.Policy

  import ExUnit.CaptureLog

  alias Expel.Rule
  alias MyApp.Policy
  alias MyApp.PolicyCombinations
  alias MyApp.PolicyShort

  describe "list_rules" do
    test "returns all rules" do
      assert Policy.list_rules() == [
               %Rule{
                 action: :create,
                 allow: [[role: :admin], [role: :writer]],
                 deny: [],
                 name: :article_create,
                 object: :article,
                 pre_hooks: []
               },
               %Rule{
                 action: :update,
                 allow: [:own_resource],
                 deny: [],
                 name: :article_update,
                 object: :article,
                 pre_hooks: [:preload_groups]
               },
               %Rule{
                 action: :view,
                 allow: [true],
                 description:
                   "allows to view an article and the list of articles",
                 deny: [],
                 name: :article_view,
                 object: :article,
                 pre_hooks: []
               },
               %Rule{
                 action: :delete,
                 allow: [[role: :admin]],
                 deny: [:same_user],
                 name: :user_delete,
                 object: :user,
                 pre_hooks: []
               },
               %Rule{
                 action: :list,
                 allow: [role: :admin, role: :client],
                 deny: [],
                 name: :user_list,
                 object: :user,
                 pre_hooks: []
               },
               %Rule{
                 action: :view,
                 allow: [
                   {:role, :admin},
                   [{:role, :client}, :same_company],
                   :same_user
                 ],
                 deny: [],
                 name: :user_view,
                 object: :user,
                 pre_hooks: []
               }
             ]
    end

    test "filters by object" do
      rules = Policy.list_rules(object: :article)
      assert Enum.all?(rules, &(&1.object == :article))

      rules = Policy.list_rules(object: :user)
      assert Enum.all?(rules, &(&1.object == :user))
    end

    test "filters by action" do
      rules = Policy.list_rules(action: :view)
      assert Enum.all?(rules, &(&1.action == :view))
    end

    test "filters by allow check name without options" do
      assert [%Rule{action: :update, object: :article}] =
               Policy.list_rules(allow: :own_resource)
    end

    test "filters by allow check name with options" do
      assert [%Rule{action: :create, object: :article}] =
               Policy.list_rules(allow: {:role, :writer})
    end

    test "filters by deny check name without options" do
      assert [%Rule{action: :delete, object: :user}] =
               Policy.list_rules(deny: :same_user)
    end
  end

  describe "get_rule/1" do
    test "returns rule" do
      assert Policy.get_rule(:article_create) == %Rule{
               action: :create,
               allow: [[role: :admin], [role: :writer]],
               deny: [],
               name: :article_create,
               object: :article,
               pre_hooks: []
             }
    end

    test "returns nil if rule is not found" do
      assert Policy.get_rule(:cookie_eat) == nil
    end
  end

  describe "fetch_rule/1" do
    test "returns rule" do
      assert Policy.fetch_rule(:article_create) ==
               {:ok,
                %Rule{
                  action: :create,
                  allow: [[role: :admin], [role: :writer]],
                  deny: [],
                  name: :article_create,
                  object: :article,
                  pre_hooks: []
                }}
    end

    test "returns :error if rule is not found" do
      assert Policy.fetch_rule(:cookie_eat) == :error
    end
  end

  describe "fetch_rule!/1" do
    test "returns rule" do
      assert Policy.fetch_rule!(:article_create) == %Rule{
               action: :create,
               allow: [[role: :admin], [role: :writer]],
               deny: [],
               name: :article_create,
               object: :article,
               pre_hooks: []
             }
    end

    test "raises error if rule is not found" do
      assert_raise KeyError, fn ->
        Policy.fetch_rule!(:cookie_eat)
      end
    end
  end

  describe "authorized?/3" do
    test "evaluates a single allow check without options" do
      assert PolicyCombinations.authorized?(
               :simple_allow_without_options,
               %{id: 1},
               %{user_id: 1}
             ) == true

      assert PolicyCombinations.authorized?(
               :simple_allow_without_options,
               %{id: 1},
               %{user_id: 2}
             ) == false
    end

    test "evaluates a single allow check with options" do
      assert PolicyCombinations.authorized?(
               :simple_allow_with_options,
               %{role: :editor}
             ) == true

      assert PolicyCombinations.authorized?(
               :simple_allow_with_options,
               %{role: :writer}
             ) == false
    end

    test "evaluates a boolean as an allow check" do
      assert PolicyCombinations.authorized?(:simple_allow_true, %{}) == true
      assert PolicyCombinations.authorized?(:simple_allow_false, %{}) == false
    end

    test "evaluates a single deny check without options" do
      assert PolicyCombinations.authorized?(
               :simple_deny_without_options,
               %{id: 1},
               %{id: 1}
             ) == false

      assert PolicyCombinations.authorized?(
               :simple_deny_without_options,
               %{id: 1},
               %{id: 2}
             ) == true
    end

    test "evaluates a single deny check with options" do
      assert PolicyCombinations.authorized?(
               :simple_deny_with_options,
               %{role: :editor}
             ) == true

      assert PolicyCombinations.authorized?(
               :simple_deny_with_options,
               %{role: :writer}
             ) == false
    end

    test "evaluates a boolean as a deny check" do
      assert PolicyCombinations.authorized?(:simple_deny_true, %{}) == false
      assert PolicyCombinations.authorized?(:simple_deny_false, %{}) == true
    end

    test "deny check without any allow checks is always false" do
      assert PolicyCombinations.authorized?(
               :simple_no_allow,
               %{id: 1},
               %{id: 1}
             ) == false

      assert PolicyCombinations.authorized?(
               :simple_no_allow,
               %{id: 1},
               %{id: 2}
             ) == false
    end

    test "action without any checks is always false" do
      assert PolicyCombinations.authorized?(:simple_no_checks, %{}) == false
    end

    test "returns false and logs warning if rule does not exist" do
      assert capture_log([level: :warn], fn ->
               assert PolicyCombinations.authorized?(:does_not_exist, %{}) ==
                        false
             end) =~ "Permission checked for rule that does not exist"
    end

    test "evaluates a list of allow checks with AND" do
      # allow [:own_resource, role: :editor]
      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_checks,
               %{id: 1, role: :editor},
               %{user_id: 1}
             ) == true

      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_checks,
               %{id: 1, role: :editor},
               %{user_id: 2}
             ) == false

      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_checks,
               %{id: 1, role: :writer},
               %{user_id: 1}
             ) == false

      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_checks,
               %{id: 1, role: :writer},
               %{user_id: 2}
             ) == false
    end

    test "evaluates a multiple allow conditions with OR" do
      # allow role: :editor
      # allow :own_resource
      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_conditions,
               %{id: 1, role: :editor},
               %{user_id: 1}
             ) == true

      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_conditions,
               %{id: 1, role: :editor},
               %{user_id: 2}
             ) == true

      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_conditions,
               %{id: 1, role: :writer},
               %{user_id: 1}
             ) == true

      assert PolicyCombinations.authorized?(
               :complex_multiple_allow_conditions,
               %{id: 1, role: :writer},
               %{user_id: 2}
             ) == false
    end

    test "evaluates a list of deny checks with AND" do
      # deny [:same_user, role: :writer]

      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_checks,
               %{id: 1, role: :writer},
               %{id: 1}
             ) == false

      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_checks,
               %{id: 1, role: :writer},
               %{id: 2}
             ) == true

      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_checks,
               %{id: 1, role: :editor},
               %{id: 1}
             ) == true

      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_checks,
               %{id: 1, role: :editor},
               %{id: 2}
             ) == true
    end

    test "evaluates a multiple deny conditions with OR" do
      # deny :same_user
      # deny role: :writer
      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_conditions,
               %{id: 1, role: :editor},
               %{id: 1}
             ) == false

      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_conditions,
               %{id: 1, role: :editor},
               %{id: 2}
             ) == true

      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_conditions,
               %{id: 1, role: :writer},
               %{id: 1}
             ) == false

      assert PolicyCombinations.authorized?(
               :complex_multiple_deny_conditions,
               %{id: 1, role: :writer},
               %{id: 2}
             ) == false
    end

    test "can configure check module with use option" do
      # Policy module is configured to use PolicyCombinations.Checks
      assert Policy.authorized?(:user_delete, %{role: :admin, id: 1}, %{id: 2})
      refute Policy.authorized?(:user_delete, %{role: :admin, id: 1}, %{id: 1})
      refute Policy.authorized?(:user_delete, %{role: :user, id: 1}, %{id: 2})
      refute Policy.authorized?(:user_delete, %{role: :user, id: 1}, %{id: 1})
    end

    test "updates subject and object with pre-hook" do
      assert PolicyCombinations.authorized?(
               :complex_single_prehook,
               %{id: 1},
               %{id: 100}
             )
    end

    test "updates subject and object with multiple pre-hooks" do
      assert PolicyCombinations.authorized?(
               :complex_multiple_prehooks,
               %{id: 1},
               %{id: 100}
             )
    end

    test "accepts module/function tuples as pre-hooks" do
      assert PolicyCombinations.authorized?(
               :complex_single_mf_prehook,
               %{id: 4},
               %{id: 100}
             )
    end

    test "accepts mfa tuples as pre-hooks" do
      assert PolicyCombinations.authorized?(
               :complex_single_mfa_prehook,
               %{id: 3},
               %{id: 100}
             )
    end
  end

  describe "authorize/3" do
    test "evaluates a single allow check without options" do
      assert PolicyCombinations.authorize(
               :simple_allow_without_options,
               %{id: 1},
               %{user_id: 1}
             ) == :ok

      assert PolicyCombinations.authorize(
               :simple_allow_without_options,
               %{id: 1},
               %{user_id: 2}
             ) == {:error, :unauthorized}
    end

    test "can configure error reason" do
      # PolicyShort module is configured to use :forbidden
      assert PolicyShort.authorize(:article_create, %{role: :nobody}) ==
               {:error, :forbidden}
    end
  end

  describe "authorize!/3" do
    test "evaluates a single allow check without options" do
      assert PolicyCombinations.authorize!(
               :simple_allow_without_options,
               %{id: 1},
               %{user_id: 1}
             ) == :ok

      assert_raise Expel.UnauthorizedError, "unauthorized", fn ->
        PolicyCombinations.authorize!(
          :simple_allow_without_options,
          %{id: 1},
          %{user_id: 2}
        )
      end
    end
  end
end
