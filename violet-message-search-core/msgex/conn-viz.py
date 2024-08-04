from pyvis.network import Network
import json
import plotly.offline as py
import plotly.graph_objects as go
import networkx as nx

from networkx.readwrite import json_graph

g = nx.Graph()

with open('./word-conn-page3.json', 'r', encoding='utf-8') as f:
    # Load the contents of the file as a JSON object
    data = json.load(f)

for char in data.keys():
    g.add_node(char, size=len(char))

for char in data.keys():
    v = []
    for co_char in data[char].keys():
        v.append([co_char, data[char][co_char]])

    v.sort(key=lambda x: x[1])
    cnt = 0
    for co_char in v:

        g.add_edge(char, co_char[0], weight=co_char[1])

        cnt += 1
        if cnt > 10:
            break

# pos_ = nx.spring_layout(g)

# nx.draw(g, pos_, with_labels=True, font_size=10,
#         node_size=500, node_color='#c2c2d6')
# nx.draw_networkx_edge_labels(
#     g, pos_, font_size=8, edge_labels=nx.get_edge_attributes(g, 'weight'))

net = Network()

net.from_nx(g)
net.show("graph.html")

exit()


def make_edge(x, y, text, width):

    return go.Scatter(x=x,
                      y=y,
                      line=dict(width=width,
                                color='cornflowerblue'),
                      hoverinfo='text',
                      text=([text]),
                      mode='lines')


edge_trace = []
for edge in g.edges():

    if g.edges()[edge]['weight'] > 0:
        char_1 = edge[0]
        char_2 = edge[1]

    x0, y0 = pos_[char_1]
    x1, y1 = pos_[char_2]
    text = char_1 + '--' + char_2 + ': ' + str(g.edges()[edge]['weight'])

    trace = make_edge([x0, x1, None], [y0, y1, None], text,
                      width=0.3*g.edges()[edge]['weight']**1.75)
    edge_trace.append(trace)

node_trace = go.Scatter(x=[],
                        y=[],
                        text=[],
                        textposition="top center",
                        textfont_size=10,
                        mode='markers+text',
                        hoverinfo='none',
                        marker=dict(color=[],
                                     size=[],
                                     line=None))

for node in g.nodes():
    x, y = pos_[node]
    node_trace['x'] += tuple([x])
    node_trace['y'] += tuple([y])
    node_trace['marker']['color'] += tuple(['cornflowerblue'])
    node_trace['marker']['size'] += tuple([5*g.nodes()[node]['size']])
    node_trace['text'] += tuple(['<b>' + node + '</b>'])

layout = go.Layout(
    paper_bgcolor='rgba(0,0,0,0)',  # transparent background
    plot_bgcolor='rgba(0,0,0,0)',  # transparent 2nd background
    xaxis={'showgrid': False, 'zeroline': False},  # no gridlines
    yaxis={'showgrid': False, 'zeroline': False},  # no gridlines
)
# Create figure
fig = go.Figure(layout=layout)
# Add all edge traces
for trace in edge_trace:
    fig.add_trace(trace)
# Add node trace
fig.add_trace(node_trace)
# Remove legend
fig.update_layout(showlegend=False)
# Remove tick labels
fig.update_xaxes(showticklabels=False)
fig.update_yaxes(showticklabels=False)
# Show figure
fig.show()
