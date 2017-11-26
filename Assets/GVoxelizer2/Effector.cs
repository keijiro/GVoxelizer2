// Geometry voxelizer effect
// https://github.com/keijiro/GVoxelizer2

using UnityEngine;
using UnityEngine.Timeline;
using System.Collections.Generic;

namespace GVoxelizer2
{
    [ExecuteInEditMode]
    [AddComponentMenu("Effects/GVoxelizer2/Effector")]
    class Effector : MonoBehaviour, ITimeControl
    {
        #region Editable attributes

        [SerializeField, Range(1, 4)] int _channel = 1;
        [SerializeField] float _offset;
        [SerializeField] Transform _targetPoint;
        [SerializeField] Renderer[] _linkedRenderers;

        #endregion

        #region Utility properties for internal use

        Vector4 EffectVector {
            get {
                var fwd = transform.forward / transform.localScale.z;
                var dist = Vector3.Dot(fwd, transform.position);
                return new Vector4(fwd.x, fwd.y, fwd.z, dist + _offset);
            }
        }

        Vector4 EffectPoint {
            get {
                if (_targetPoint == null)
                    return Vector3.zero;
                else
                    return _targetPoint.position;
            }
        }

        float LocalTime {
            get {
                if (_controlTime < 0)
                    return Application.isPlaying ? Time.time : 0;
                else
                    return _controlTime;
            }
        }

        #endregion

        #region ITimeControl implementation

        float _controlTime = -1;

        public void OnControlTimeStart()
        {
        }

        public void OnControlTimeStop()
        {
            _controlTime = -1;
        }

        public void SetTime(double time)
        {
            _controlTime = (float)time;
        }

        #endregion

        #region MonoBehaviour implementation

        MaterialPropertyBlock _sheet;

        void Update()
        {
            if (_linkedRenderers == null || _linkedRenderers.Length == 0) return;

            if (_sheet == null) _sheet = new MaterialPropertyBlock();

            var ev = EffectVector;
            var ep = EffectPoint;
            var time = LocalTime;

            foreach (var renderer in _linkedRenderers)
            {
                renderer.GetPropertyBlock(_sheet);
                _sheet.SetVector("_EffectVector" + _channel, ev);
                _sheet.SetVector("_EffectPoint" + _channel, ep);
                _sheet.SetFloat("_LocalTime", time);
                renderer.SetPropertyBlock(_sheet);
            }
        }

        #endregion

        #region Editor gizmo implementation

        #if UNITY_EDITOR

        Mesh _gridMesh;

        void OnDestroy()
        {
            if (_gridMesh != null)
            {
                if (Application.isPlaying)
                    Destroy(_gridMesh);
                else
                    DestroyImmediate(_gridMesh);
            }
        }

        void OnDrawGizmos()
        {
            if (_gridMesh == null) InitGridMesh();

            if (_targetPoint != null)
            {
                Gizmos.color = Color.cyan;
                Gizmos.DrawWireSphere(_targetPoint.position, 0.1f);
            }

            Gizmos.matrix = transform.localToWorldMatrix;

            var p1 = Vector3.forward * _offset;
            var p2 = Vector3.forward * (_offset + 1);

            Gizmos.color = new Color(1, 1, 0, 0.5f);
            Gizmos.DrawWireMesh(_gridMesh, p1);
            Gizmos.DrawWireMesh(_gridMesh, p2);

            Gizmos.color = new Color(1, 0, 0, 0.5f);
            Gizmos.DrawWireCube((p1 + p2) / 2, new Vector3(0.02f, 0.02f, 1));
        }

        void InitGridMesh()
        {
            const float ext = 0.5f;
            const int columns = 10;

            var vertices = new List<Vector3>();
            var indices = new List<int>();

            for (var i = 0; i < columns + 1; i++)
            {
                var x = ext * (2.0f * i / columns - 1);

                indices.Add(vertices.Count);
                vertices.Add(new Vector3(x, -ext, 0));

                indices.Add(vertices.Count);
                vertices.Add(new Vector3(x, +ext, 0));

                indices.Add(vertices.Count);
                vertices.Add(new Vector3(-ext, x, 0));

                indices.Add(vertices.Count);
                vertices.Add(new Vector3(+ext, x, 0));
            }

            _gridMesh = new Mesh();
            _gridMesh.hideFlags = HideFlags.DontSave;
            _gridMesh.SetVertices(vertices);
            _gridMesh.SetNormals(vertices);
            _gridMesh.SetIndices(indices.ToArray(), MeshTopology.Lines, 0);
            _gridMesh.UploadMeshData(true);
        }

        #endif

        #endregion
    }
}
