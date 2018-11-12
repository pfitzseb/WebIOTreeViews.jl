module WebIOTreeViews

using WebIO, Observables, TreeViews, JSExpr

function bestlabel(f, args...)
  return applicable(f, IOBuffer(), args..., MIME"text/html"()) ?
            HTML(sprint(f, args..., MIME"text/html"())) :
            Text(sprint(f, args..., MIME"text/plain"()))
end

mutable struct Tree{F}
    head
    children
    children_fun::F
    materialized::Bool
end

function Tree(head, children::Vector)
  Tree(head, children, identity, true)
end

function Tree(head, fun::Function)
  Tree(head, [], fun, false)
end

function towebio(x::Tree)
  w = Scope()
  showval = Observable(w, "showval", false)
  children = Observable(w, "children", x.children)

  w.dom = dom"div.tree"(dom"div.header"(map(t -> dom"span"(t ? "v " : "> ", sprint(show, x.head), style = Dict("display" => "inline")), showval), events = Dict("click" => js"""
    function (e) {
      console.log(e);
      var dom = this.parentElement.getElementsByClassName("children")[0];
      var showval = !_webIOScope.getObservableValue("showval")
      console.log(showval)
      dom.style.display = showval ? "block" : "none";
      _webIOScope.setObservableValue("showval", showval);
    }
    """)), dom"div.children"(map(cs -> dom"div"(cs..., style = Dict("padding-left" => "1em")), children), style = Dict("display" => "none")), style = Dict("color" => "white", "cursor" => "default"))

  on(showval) do val
    x.materialized && return nothing
    x.children = x.children_fun()
    children[] = towebio.(x.children)
    # @show children[]
    x.materialized = true
  end

  return w
end

function webiotreeview(x)
  header = bestlabel(TreeViews.treelabel, x)
  TreeViews.numberofnodes(x) == 0 &&  return Tree(header, [])

  genchildren = function ()
    children = Any[]
    for i in 1:TreeViews.numberofnodes(x)
      node = TreeViews.treenode(x, i)
      cheader = bestlabel(TreeViews.nodelabel, x, i)

      if isempty(cheader.content)
        node === missing && continue
        push!(children, TreeViews.hastreeview(node) ? towebio(webiotreeview(node)) : node)
      elseif node === missing
        push!(children, cheader)
      else
        push!(children, Tree(Text("$cheader → "), [TreeViews.hastreeview(node) ? towebio(webiotreeview(node)) : node]))
      end
    end
    children
  end

  return Tree(header, genchildren)
end

end # module
