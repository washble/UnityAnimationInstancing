using System.Collections;
using UnityEngine;

public class TestSpawner : MonoBehaviour
{
    [SerializeField] private int maxSpawnCount = 400;
    [SerializeField] private GameObject characterPrefab;
    [SerializeField] private GameObject attachObject;

    private float offset = 2;
    Vector3 spawnerPosition;
    private WaitForSeconds wait = new(0.01f);
    
    void Start()
    {
        spawnerPosition = transform.position;
        StartCoroutine(Spawn());
    }

    private void OnDestroy()
    {
        StopAllCoroutines();
    }

    private IEnumerator Spawn()
    {
        yield return StartCoroutine(AnimationManager.Instance.LoadAnimationAssetBundle($"{Application.streamingAssetsPath}/animationtexture"));
        
        int x = 0;
        int z = 0;
        for (int i = 0; i < maxSpawnCount; i++)
        {
            if (x > 100)
            {
                x = 0;
                z++;
            }
            Copy(x++, z);
#if UNITY_EDITOR
            Debug.Log($"Create Number{i} Character.");
#endif
            yield return wait;
        }   
    }

    private void Copy(int x, int z)
    {
        
        GameObject character = Instantiate(characterPrefab, spawnerPosition + new Vector3(x * offset, 0, z), Quaternion.identity, null);
        character.name = characterPrefab.name;
        URPAnimationInstancing animationIns = character.GetComponent<URPAnimationInstancing>();
        CharacterMove move = character.GetComponent<CharacterMove>();
        animationIns.prototype = character;

        if (attachObject)
        {
            GameObject weapon = Instantiate(attachObject, null);
            weapon.name = attachObject.name;
            move.attachAnimationInstancing = weapon.GetComponent<URPAnimationInstancing>();
            
            weapon.SetActive(true);
        }
        
        character.SetActive(true);
    }
}
