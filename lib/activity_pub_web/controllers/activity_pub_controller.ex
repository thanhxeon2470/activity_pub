defmodule ActivityPubWeb.ActivityPubController do
  @moduledoc """

  Endpoints for serving objects and collections, so the ActivityPub API can be used to read information from the server.

  Even though we store the data in AS format, some changes need to be applied to the entity before serving it in the AP REST response. This is done in `ActivityPubWeb.ActivityPubView`.
  """

  use ActivityPubWeb, :controller

  import Where

  alias ActivityPub.Actor
  alias ActivityPub.Fetcher
  alias ActivityPub.Object
  alias ActivityPub.Utils
  alias ActivityPubWeb.ActorView
  alias ActivityPubWeb.Federator
  alias ActivityPubWeb.ObjectView
  alias ActivityPubWeb.RedirectController

  def ap_route_helper(uuid) do
    ap_base_path = System.get_env("AP_BASE_PATH", "/pub")

    ActivityPubWeb.base_url() <> ap_base_path <> "/objects/" <> uuid
  end

  def object(conn, %{"uuid" => uuid}) do
    if get_format(conn) == "html" do
      RedirectController.object(conn, %{"uuid" => uuid})
    else # json
      if Utils.is_ulid?(uuid) do # querying by pointer
        with %Object{} = object <- Object.get_cached_by_pointer_id(uuid),
            true <- object.public,
            true <- object.id != uuid do
          conn
          |> put_resp_content_type("application/activity+json")
          |> put_view(ObjectView)
          |> render("object.json", %{object: object})
          # |> Phoenix.Controller.redirect(external: ap_route_helper(object.id))
          # |> halt()
        else
          _ ->
            conn
            |> put_status(404)
            |> json(%{error: "not found"})
        end
      else
        with ap_id <- ap_route_helper(uuid),
            %Object{} = object <- Object.get_cached_by_ap_id(ap_id),
            true <- object.public do
          conn
          |> put_resp_content_type("application/activity+json")
          |> put_view(ObjectView)
          |> render("object.json", %{object: object})
        else _ ->
          conn
          |> put_status(404)
          |> json(%{error: "not found"})
        end
      end
    end
  end

  def actor(conn, %{"username" => username}) do
    if get_format(conn) == "html" do
      RedirectController.actor(conn, %{"username" => username})
    else # json
      with {:ok, actor} <- Actor.get_cached_by_username(username) do
        conn
        |> put_resp_content_type("application/activity+json")
        |> put_view(ActorView)
        |> render("actor.json", %{actor: actor})
      else
        _ ->
          conn
          |> put_status(404)
          |> json(%{error: "not found"})
      end
    end
  end

  def following(conn, %{"username" => username, "page" => page}) do
    with {:ok, actor} <- Actor.get_cached_by_username(username) do
      {page, _} = Integer.parse(page)

      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(ActorView)
      |> render("following.json", %{actor: actor, page: page})
    end
  end

  def following(conn, %{"username" => username}) do
    with {:ok, actor} <- Actor.get_cached_by_username(username) do
      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(ActorView)
      |> render("following.json", %{actor: actor})
    end
  end

  def followers(conn, %{"username" => username, "page" => page}) do
    with {:ok, actor} <- Actor.get_cached_by_username(username) do
      {page, _} = Integer.parse(page)

      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(ActorView)
      |> render("followers.json", %{actor: actor, page: page})
    end
  end

  def followers(conn, %{"username" => username}) do
    with {:ok, actor} <- Actor.get_cached_by_username(username) do
      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(ActorView)
      |> render("followers.json", %{actor: actor})
    end
  end

  def outbox(conn, %{"username" => username, "page" => page}) do
    with {:ok, actor} <- Actor.get_cached_by_username(username) do
      {page, _} = Integer.parse(page)

      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(ObjectView)
      |> render("outbox.json", %{actor: actor, page: page})
    end
  end

  def outbox(conn, %{"username" => username}) do
    with {:ok, actor} <- Actor.get_cached_by_username(username) do
      conn
      |> put_resp_content_type("application/activity+json")
      |> put_view(ObjectView)
      |> render("outbox.json", %{actor: actor})
    end
  end

  def inbox(%{assigns: %{valid_signature: true}} = conn, params) do
    Federator.incoming_ap_doc(params)
    json(conn, "ok")
  end

  # only accept relayed Creates
  def inbox(conn, %{"type" => "Create"} = params) do
    warn(
      params,
      "Signature missing or not from author, relayed Create message, fetching object from source"
    )

    Fetcher.fetch_object_from_id(params["object"]["id"])

    json(conn, "ok")
  end

  # heck u mastodon
  def inbox(conn, %{"type" => "Delete"}) do
    json(conn, "ok")
  end

  def inbox(conn, params) do
    headers = Enum.into(conn.req_headers, %{})

    if String.contains?(headers["signature"], params["actor"]) do
      warn(
        params["actor"],
        "Signature validation error, make sure you are forwarding the HTTP Host header"
      )
      debug(conn.req_headers)
    end

    json(conn, dgettext("errors", "error"))
  end

  def noop(conn, _params) do
    json(conn, "ok")
  end
end
